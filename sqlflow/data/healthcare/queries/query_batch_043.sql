-- Query 1
WITH RecentVisits AS (
    SELECT v.visit_id, v.patient_id, v.visit_date
    FROM visits v
    WHERE v.visit_date > CURRENT_DATE - INTERVAL '30 days'
),
ExtendedVisits AS (
    SELECT rv.visit_id, rv.visit_date, p.first_name, p.last_name, COUNT(di.diagnosis_id) AS diagnosis_count
    FROM RecentVisits rv
    JOIN diagnoses di ON rv.visit_id = di.visit_id
    JOIN patients p ON rv.patient_id = p.patient_id
    GROUP BY rv.visit_id, rv.visit_date, p.first_name, p.last_name
)
SELECT ev.*, 
       CASE WHEN ev.diagnosis_count > 3 THEN 'High' ELSE 'Low' END AS diagnosis_risk
FROM ExtendedVisits ev;

-- Query 2
WITH ProviderActivity AS (
    SELECT p.provider_id, COUNT(DISTINCT v.visit_id) AS visit_count
    FROM providers p
    JOIN visits v ON p.provider_id = v.provider_id
    WHERE v.visit_date BETWEEN '2023-01-01' AND '2023-12-31'
    GROUP BY p.provider_id
),
TopProviders AS (
    SELECT provider_id
    FROM ProviderActivity
    WHERE visit_count > 50
)
SELECT tp.provider_id, p.first_name, p.last_name, e.encounter_type_name
FROM TopProviders tp
JOIN visits v ON tp.provider_id = v.provider_id
JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id;

-- Query 3
WITH PatientConditions AS (
    SELECT patient_id, COUNT(condition_id) AS condition_count
    FROM conditions
    WHERE condition_status = 'active'
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, pc.condition_count,
       i.payer_name, i.plan_type
FROM PatientConditions pc
JOIN patients p ON pc.patient_id = p.patient_id
LEFT JOIN insurance i ON p.insurance_id = i.insurance_id
WHERE pc.condition_count > 2;

-- Query 4
WITH EmergencyVisits AS (
    SELECT v.visit_id, v.patient_id, v.visit_date, v.was_emergency
    FROM visits v
    WHERE v.was_emergency = TRUE
),
DetailedVisits AS (
    SELECT ev.visit_id, ev.visit_date, p.first_name, p.last_name,
           ROUND(AVG(l.result_value), 2) AS avg_lab_result
    FROM EmergencyVisits ev
    JOIN patients p ON ev.patient_id = p.patient_id
    JOIN labs l ON ev.visit_id = l.visit_id
    WHERE l.result_flag = 'abnormal'
    GROUP BY ev.visit_id, ev.visit_date, p.first_name, p.last_name
)
SELECT dv.*, COUNT(a.allergy_id) AS allergy_count
FROM DetailedVisits dv
LEFT JOIN allergies a ON dv.patient_id = a.patient_id
GROUP BY dv.visit_id, dv.visit_date, dv.first_name, dv.last_name;

-- Query 5
WITH RecentMedications AS (
    SELECT DISTINCT m.visit_id, m.medication_name
    FROM medications m
    WHERE m.start_date > CURRENT_DATE - INTERVAL '90 days'
),
ProcedureData AS (
    SELECT v.visit_id, p.procedure_code
    FROM visits v
    JOIN procedures p ON v.visit_id = p.visit_id
)
SELECT pm.visit_id, COUNT(DISTINCT pd.procedure_code) AS procedure_count,
       pm.medication_name
FROM RecentMedications pm
JOIN ProcedureData pd ON pm.visit_id = pd.visit_id
GROUP BY pm.visit_id, pm.medication_name
HAVING COUNT(DISTINCT pd.procedure_code) > 1;

-- Query 6
WITH AllergySummary AS (
    SELECT patient_id, COUNT(allergy_id) AS total_allergies
    FROM allergies
    GROUP BY patient_id
),
IncomeSummary AS (
    SELECT patient_id, income_level
    FROM income_brackets
    WHERE recorded_date = (SELECT MAX(recorded_date) FROM income_brackets)
)
SELECT a.patient_id, a.total_allergies, i.income_level, AVG(paid_amount) AS avg_paid_amount
FROM AllergySummary a
JOIN IncomeSummary i ON a.patient_id = i.patient_id
JOIN claims c ON a.patient_id = c.patient_id
GROUP BY a.patient_id, i.income_level;

-- Query 7
WITH PatientRiskAggregation AS (
    SELECT rs.patient_id, AVG(rs.score_value) AS avg_risk_score
    FROM risk_scores rs
    WHERE rs.calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY rs.patient_id
)
SELECT pra.patient_id, pra.avg_risk_score, COUNT(e.employment_id) AS employment_changes
FROM PatientRiskAggregation pra
JOIN employment_status e ON pra.patient_id = e.patient_id
GROUP BY pra.patient_id, pra.avg_risk_score;

-- Query 8
WITH TeamPatients AS (
    SELECT pct.patient_id, ct.team_name
    FROM patient_care_team pct
    JOIN care_teams ct ON pct.care_team_id = ct.care_team_id
)
SELECT tp.team_name, COUNT(DISTINCT p.patient_id) AS unique_patients
FROM TeamPatients tp
JOIN patients p ON tp.patient_id = p.patient_id
GROUP BY tp.team_name
HAVING COUNT(DISTINCT p.patient_id) > 5;

-- Query 9
WITH VisitClaimRatio AS (
    SELECT v.visit_id, v.patient_id, COUNT(c.claim_id) AS claim_count
    FROM visits v
    LEFT JOIN claims c ON v.visit_id = c.visit_id
    GROUP BY v.visit_id, v.patient_id
)
SELECT vcr.patient_id, SUM(vcr.claim_count) AS total_claims,
       CASE 
           WHEN SUM(vcr.claim_count) > 10 THEN 'High'
           ELSE 'Low'
       END AS claim_activity
FROM VisitClaimRatio vcr
GROUP BY vcr.patient_id;

-- Query 10
WITH VitalsSummary AS (
    SELECT v.visit_id, AVG(vi.bmi) AS avg_bmi, MAX(vi.heart_rate) AS max_heart_rate
    FROM vitals vi
    JOIN visits v ON vi.visit_id = v.visit_id
    GROUP BY v.visit_id
)
SELECT vs.visit_id, vs.avg_bmi, vs.max_heart_rate, p.first_name, p.last_name
FROM VitalsSummary vs
JOIN visits v ON vs.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
ORDER BY vs.max_heart_rate DESC;