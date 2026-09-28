/**
 * Pauses only the nine intended SchoolDesk cron jobs while the API is in
 * maintenance mode. It never removes a schedule or imports historical runs.
 */

const RETAINED = [
  "purge-expired-notifications",
  "enforce-error-event-retention",
  "purge-realtime-invalidations",
  "queue-fee-reminders-daily",
  "generate-current-daycare-invoices",
];
const RESTORED = [
  "process-notification-events",
  "daily-birthday-alerts-morning",
  "daily-birthday-alerts-afternoon",
  "daily-health-reminders-4pm-ist",
];

type DatabaseClient = any;

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

const enable = Deno.args.includes("--enable");
const disable = Deno.args.includes("--disable");
if (enable === disable) {
  throw new Error("Use exactly one of --enable or --disable");
}

const expected = enable ? RETAINED : [...RETAINED, ...RESTORED];
const report = await withDatabase(async (sql) => {
  const jobs = await sql`
    select jobid, jobname, active
    from cron.job
    where jobname = any(${expected})
    order by jobname
  ` as Array<{ jobid: number; jobname: string; active: boolean }>;
  const missing = expected.filter((name) =>
    !jobs.some((job) => job.jobname === name)
  );
  if (missing.length) {
    throw new Error(`Expected cron job(s) are absent: ${missing.join(", ")}`);
  }
  await sql.begin(async (tx: DatabaseClient) => {
    for (const job of jobs) {
      await tx`select cron.alter_job(${job.jobid}, active => ${!enable})`;
    }
  });
  const after = await sql`
    select jobname, active
    from cron.job
    where jobname = any(${expected})
    order by jobname
  ` as Array<{ jobname: string; active: boolean }>;
  if (after.some((job) => job.active !== !enable)) {
    throw new Error("Cron maintenance state verification failed");
  }
  return after;
});

console.log(JSON.stringify({ maintenance: enable, jobs: report }, null, 2));
