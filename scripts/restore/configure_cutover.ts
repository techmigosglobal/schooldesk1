/** Configures fresh target-only scheduler secrets and the four approved jobs. */

const TARGET_URL = "https://qzdhymlabzqjeocetqqv.supabase.co";
const RETAINED = new Set([
  "purge-expired-notifications",
  "enforce-error-event-retention",
  "purge-realtime-invalidations",
  "queue-fee-reminders-daily",
  "generate-current-daycare-invoices",
]);

type DatabaseClient = any;

type Job = { name: string; schedule: string; command: string };

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function withDatabase<T>(callback: (sql: DatabaseClient) => Promise<T>) {
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(required("TARGET_DB_URL"), {
    max: 1,
    prepare: false,
    idle_timeout: 0,
    connect_timeout: 15,
  });
  try {
    return await callback(sql);
  } finally {
    await sql.end({ timeout: 5 }).catch(() => undefined);
  }
}

function jobs(): Job[] {
  return [
    {
      name: "process-notification-events",
      schedule: "*/2 * * * *",
      command: `select net.http_post(
        url := '${TARGET_URL}/functions/v1/notification-processor',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || private.restore_scheduler_secret('NOTIFICATION_PROCESSOR_SECRET'),
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object('source', 'pg_cron')
      );`,
    },
    {
      name: "daily-birthday-alerts-morning",
      schedule: "30 3 * * *",
      command: `select net.http_post(
        url := '${TARGET_URL}/functions/v1/api/jobs/birthday-alerts/run',
        headers := jsonb_build_object(
          'x-job-secret', private.restore_scheduler_secret('BIRTHDAY_ALERT_JOB_SECRET'),
          'Content-Type', 'application/json'
        ),
        body := '{"delivery_window":"morning"}'::jsonb
      );`,
    },
    {
      name: "daily-birthday-alerts-afternoon",
      schedule: "30 9 * * *",
      command: `select net.http_post(
        url := '${TARGET_URL}/functions/v1/api/jobs/birthday-alerts/run',
        headers := jsonb_build_object(
          'x-job-secret', private.restore_scheduler_secret('BIRTHDAY_ALERT_JOB_SECRET'),
          'Content-Type', 'application/json'
        ),
        body := '{"delivery_window":"afternoon"}'::jsonb
      );`,
    },
    {
      name: "daily-health-reminders-4pm-ist",
      schedule: "30 10 * * *",
      command: `select net.http_post(
        url := '${TARGET_URL}/functions/v1/api/jobs/health-reminders/run',
        headers := jsonb_build_object(
          'x-job-secret', private.restore_scheduler_secret('HEALTH_REMINDER_JOB_SECRET'),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
      );`,
    },
  ];
}

async function main() {
  const secrets = [
    "NOTIFICATION_PROCESSOR_SECRET",
    "BIRTHDAY_ALERT_JOB_SECRET",
    "HEALTH_REMINDER_JOB_SECRET",
  ].map((name) => ({ name, value: required(name) }));
  const requested = jobs();
  const report = await withDatabase(async (sql) => {
    const before = await sql`
      select jobname, schedule
      from cron.job
      order by jobname
    ` as Array<{ jobname: string; schedule: string }>;
    const missingRetained = [...RETAINED].filter((name) =>
      !before.some((job) => job.jobname === name)
    );
    if (missingRetained.length) {
      throw new Error(
        `Target is missing retained cron jobs: ${missingRetained.join(", ")}`,
      );
    }

    await sql.begin(async (tx: DatabaseClient) => {
      for (const secret of secrets) {
        await tx`delete from vault.secrets where name = ${secret.name}`;
        await tx`select vault.create_secret(${secret.value}, ${secret.name}, 'SchoolDesk target restore scheduler secret')`;
      }
      for (const job of requested) {
        await tx`select cron.unschedule(${job.name}) where exists (select 1 from cron.job where jobname = ${job.name})`;
        await tx`select cron.schedule(${job.name}, ${job.schedule}, ${job.command})`;
        // The API remains in maintenance mode until final acceptance. Keep
        // newly added schedules inactive so no job creates an interim run.
        const scheduled = await tx`
          select jobid
          from cron.job
          where jobname = ${job.name}
        ` as Array<{ jobid: number }>;
        await tx`select cron.alter_job(${scheduled[0].jobid}, active => false)`;
      }
    });

    const after = await sql`
      select jobname, schedule
      from cron.job
      order by jobname
    ` as Array<{ jobname: string; schedule: string }>;
    const expected = [...RETAINED, ...requested.map((job) => job.name)];
    const missing = expected.filter((name) =>
      !after.some((job) => job.jobname === name)
    );
    const demoRotation = after.some((job) =>
      job.jobname === "rotate-schooldesk-demo-credential"
    );
    if (missing.length || demoRotation) {
      throw new Error(
        `Cron verification failed; missing=${
          missing.join(",") || "none"
        }, demo_rotation=${demoRotation}`,
      );
    }
    return after.filter((job) => expected.includes(job.jobname));
  });
  console.log(JSON.stringify(
    {
      target: TARGET_URL,
      fresh_scheduler_secrets: secrets.map(({ name }) => name),
      jobs: report,
    },
    null,
    2,
  ));
}

await main();
