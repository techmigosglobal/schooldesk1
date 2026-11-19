#!/usr/bin/env python3
"""Exercise payment-proof decisions against the synthetic local API and database."""

import json
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier

CONFIG = json.loads(
    (Path(__file__).resolve().parent.parent / "env.local.json").read_text()
)
API = CONFIG["API_BASE_URL"].rstrip("/")
assert urllib.parse.urlparse(API).hostname in ("localhost", "127.0.0.1", "::1")
REQUESTS = "/fees/payment-requests"


def sql(statement):
    result = subprocess.run(
        [
            "docker", "--context", "default", "exec", "-i",
            "supabase_db_schooldesk-local",
            "psql", "-X", "-U", "postgres", "-d", "postgres",
            "-v", "ON_ERROR_STOP=1", "-Atq",
        ],
        input=statement,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def request(path, method, token=None, *, body=None, form=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    if form is not None:
        boundary = "schooldesk-local-proof-smoke"
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        data = (
            "".join(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'
                for key, value in form.items()
            ) + f"--{boundary}--\r\n"
        ).encode()
    req = urllib.request.Request(API + path, data, headers, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=60)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response)


def checked(response, expected):
    status, body = response
    assert status == expected, (status, expected, body.get("error"))
    return body.get("data")


def login(role):
    return checked(request("/auth/login", "POST", body={
        "username": CONFIG[f"QA_{role}_USERNAME"],
        "password": CONFIG[f"QA_{role}_PASSWORD"],
    }), 200)


def run():
    parent = login("PARENT")
    principal, coordinator, other_school = (
        login(role)["access_token"]
        for role in ("PRINCIPAL", "COORDINATOR", "SECOND_SCHOOL_PRINCIPAL")
    )
    parent_id = uuid.UUID(parent["user"]["id"])
    parent_token = parent["access_token"]
    invoice_id, structure_id = uuid.uuid4(), uuid.uuid4()
    race_id, clarification_id = uuid.uuid4(), uuid.uuid4()
    request_ids = f"('{race_id}', '{clarification_id}')"

    sql(f"""
        begin;
        insert into public.fee_structures (
          id, school_id, academic_year_id, category_id, is_active
        )
        select '{structure_id}', i.school_id, i.academic_year_id, fs.category_id, false
        from public.fee_invoices i
        join public.fee_structures fs on fs.id = i.fee_structure_id
        join public.parent_student_links link
          on link.school_id = i.school_id and link.student_id = i.student_id
        where link.parent_user_id = '{parent_id}' order by i.id limit 1;
        insert into public.fee_invoices (
          id, school_id, student_id, academic_year_id, fee_structure_id,
          invoice_number, total_amount, net_amount, balance, status
        )
        select '{invoice_id}', fs.school_id, link.student_id, fs.academic_year_id,
          fs.id, 'LOCAL-PROOF-{invoice_id}', 100, 100, 100, 'unpaid'
        from public.fee_structures fs
        join public.parent_student_links link using (school_id)
        where fs.id = '{structure_id}' and link.parent_user_id = '{parent_id}'
        order by link.student_id limit 1;
        insert into public.parent_payment_requests (
          id, school_id, student_id, invoice_id, parent_user_id, amount, status
        )
        select '{race_id}', school_id, student_id, id, '{parent_id}', 20, 'pending'
        from public.fee_invoices where id = '{invoice_id}';
        commit;
    """)

    def decide(proof_id, status, token=principal, remarks="Local review"):
        return request(f"{REQUESTS}/{proof_id}/decision", "PUT", token, body={
            "status": status, "admin_remarks": remarks,
        })

    def resubmit(proof_id):
        return request(f"/fees/payments/{proof_id}/resubmit", "PATCH", parent_token,
                       form={"transaction_ref": "LOCAL-CLARIFIED"})

    try:
        checked(decide(race_id, "approved", parent_token), 403)
        checked(decide(race_id, "approved", coordinator), 403)
        checked(decide(race_id, "approved", other_school), 404)
        gate = Barrier(2, timeout=20)

        def race(status):
            gate.wait()
            return status, decide(race_id, status)

        with ThreadPoolExecutor(max_workers=2) as pool:
            attempts = list(pool.map(race, ("approved", "rejected")))
        assert sorted(response[0] for _, response in attempts) == [200, 409]
        status, first = next((state, response) for state, response in attempts if response[0] == 200)
        decided = checked(first, 200)
        assert decided["status"] == status
        assert sql(f"select balance from fee_invoices where id = '{invoice_id}';") == (
            "80.00" if status == "approved" else "100.00"
        )
        assert sql(f"select count(*) from payments where invoice_id = '{invoice_id}';") == (
            "1" if status == "approved" else "0"
        )
        checked(resubmit(race_id), 409)
        checked(request("/fees/payments/submit", "POST", parent_token,
                        form={"payment_request_id": str(race_id)}), 409)

        sql(f"""
            insert into public.parent_payment_requests (
              id, school_id, student_id, invoice_id, parent_user_id, amount, status
            )
            select '{clarification_id}', school_id, student_id, id, '{parent_id}', 10, 'submitted'
            from public.fee_invoices where id = '{invoice_id}';
        """)
        checked(decide(clarification_id, "clarification_required"), 200)
        assert checked(resubmit(clarification_id), 200)["status"] == "pending_verification"
        checked(resubmit(clarification_id), 409)
        approved = checked(decide(clarification_id, "approved"), 200)
        replay = checked(decide(clarification_id, "approved"), 200)
        assert approved["payment_id"] == replay["payment_id"]
        assert approved["receipt_id"] == replay["receipt_id"]
        checked(decide(clarification_id, "approved", remarks="Changed decision"), 409)
        parent_rows = checked(request(
            f"{REQUESTS}?invoice_id={invoice_id}", "GET", parent_token,
        ), 200)
        parent_approval = next(row for row in parent_rows if row["id"] == str(clarification_id))
        assert parent_approval["status"] == "approved"
        assert parent_approval["receipt"]["id"] == approved["receipt_id"]
        assert sql(f"""
            select count(*) from notification_events
            where event_type = 'fee_payment_approved'
              and event_data->>'payment_request_id' = '{clarification_id}';
        """) == "1"
        print("PASS concurrent decision, exact replay, approval notification, parent receipt, scope and resubmission")
    finally:
        sql(f"""
            begin;
            delete from public.notification_events
            where event_data->>'payment_request_id' in {request_ids};
            delete from public.notification_logs
            where entity_type = 'parent_payment_requests' and entity_id in {request_ids};
            delete from public.parent_payment_requests where invoice_id = '{invoice_id}';
            delete from public.finance_document_snapshots where invoice_id = '{invoice_id}';
            delete from public.fee_receipts where invoice_id = '{invoice_id}';
            delete from public.payments where invoice_id = '{invoice_id}';
            delete from public.fee_invoices where id = '{invoice_id}';
            delete from public.fee_structures where id = '{structure_id}';
            commit;
        """)


if __name__ == "__main__":
    run()
