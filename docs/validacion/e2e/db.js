const { execSync } = require('child_process');
function q(sql) { return execSync(`PGPASSWORD=x psql -h localhost -U postgres -d fitsense_e2e -At -F '|' -c "${sql.replace(/"/g, '\\"')}"`).toString().trim(); }
function op(email) { return q(`SELECT o.status, coalesce(o.plan_id::text,'-'), coalesce(o.reason_code,'-'), o.executions FROM plan_generation_operations o JOIN users u USING (user_id) WHERE u.email='${email}' ORDER BY o.created_at DESC LIMIT 1`); }
function counts(email) { return q(`SELECT (SELECT count(*) FROM plan_generation_operations o JOIN users u USING (user_id) WHERE u.email='${email}') || ' ops, ' || (SELECT count(*) FROM weekly_training_plans p JOIN users u USING (user_id) WHERE u.email='${email}') || ' planes'`); }
module.exports = { q, op, counts };
