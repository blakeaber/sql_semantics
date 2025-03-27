-- Query 1
WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)
SELECT p.patient_id, 
       CONCAT(p.first_name, ' ', p.last_name) AS full_name,
       COUNT(v.visit_id) AS total_visits,
       AVG(pr.amount) OVER (PARTITION BY p.patient_id) AS avg_payment,
       CASE WHEN MAX(last_visit_date) < CURRENT_DATE - INTERVAL '1 year' 
            THEN 'Inactive' ELSE 'Active' END AS patient_status
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN (SELECT claim_id, SUM(amount) AS amount FROM payments GROUP BY claim_id) pr 
     ON v.visit_id IN (SELECT visit_id FROM claims WHERE claim_id = pr.claim_id)
JOIN RecentVisits rv ON rv.patient_id = p.patient_id
GROUP BY p.patient_id, full_name
HAVING COUNT(v.visit_id) > 5;

-- Query 2
WITH ConditionFrequency AS (
    SELECT condition_name, COUNT(*) AS frequency
    FROM conditions
    GROUP BY condition_name
)
SELECT c.patient_id, 
       cond.condition_name,
       cond.diagnosed_date,
       AVG(b.amount) OVER (PARTITION BY cond.condition_name) AS avg_claim_amount,
       COALESCE(i.group_number, 'Unknown') AS insurance_group
FROM conditions cond
JOIN claims c ON cond.patient_id = c.patient_id AND cond.diagnosed_date = c.claim_date
JOIN billing b ON c.claim_id = b.claim_id
LEFT JOIN insurance i ON i.insurance_id = c.patient_id
WHERE cond.condition_name IN (
    SELECT condition_name FROM ConditionFrequency WHERE frequency > 50
)
ORDER BY cond.diagnosed_date DESC;

-- Query 3
WITH MonthlyAllergies AS (
    SELECT patient_id, 
           EXTRACT(MONTH FROM recorded_date) AS month,
           COUNT(allergy_id) AS allergy_count
    FROM allergies
    GROUP BY patient_id, month
)
SELECT a.patient_id,
       mnth.allergy_count,
       r.race_ethnicity_name,
       AVG(lv.result_value) OVER (PARTITION BY a.patient_id, a.severity) AS avg_lab_value
FROM allergies a
JOIN MonthlyAllergies mnth ON a.patient_id = mnth.patient_id
JOIN race_ethnicity r ON r.race_ethnicity_id = a.patient_id
LEFT JOIN labs lv ON lv.visit_id = a.patient_id
WHERE mnth.allergy_count > 5
AND a.severity IN ('High', 'Medium');

-- Query 4
WITH HighRiskScores AS (
    SELECT patient_id, MAX(score_value) AS max_score
    FROM risk_scores
    WHERE score_value > 80
    GROUP BY patient_id
)
SELECT rs.patient_id,
       MAX(rs.calculated_date) AS last_calculated,
       COALESCE(srv.survey_score, 0) AS latest_survey_score,
       CASE 
           WHEN MAX(rs.score_value) OVER (PARTITION BY rs.patient_id) > 90 THEN 'Critical'
           ELSE 'High'
       END AS risk_status
FROM risk_scores rs
JOIN HighRiskScores hrs ON rs.patient_id = hrs.patient_id
LEFT JOIN surveys srv ON srv.patient_id = rs.patient_id
GROUP BY rs.patient_id, srv.survey_score;

-- Query 5
WITH ProviderSpecialityStats AS (
    SELECT provider_id, specialty, COUNT(*) AS visit_count
    FROM providers
    JOIN visits v ON providers.provider_id = v.provider_id
    GROUP BY provider_id, specialty
),
RecentLabs AS (
    SELECT visit_id, result_flag FROM labs WHERE reported_date > CURRENT_DATE - INTERVAL '6 months'
)
SELECT pr.provider_id,
       pr.specialty,
       prov_stats.visit_count,
       CASE 
           WHEN SUM(CASE WHEN rl.result_flag = 'A' THEN 1 ELSE 0 END) > 10 THEN 'High Alert'
           ELSE 'Normal'
       END AS lab_alert_status
FROM providers pr
JOIN ProviderSpecialityStats prov_stats ON pr.provider_id = prov_stats.provider_id
JOIN visits v ON v.provider_id = pr.provider_id
LEFT JOIN RecentLabs rl ON v.visit_id = rl.visit_id
GROUP BY pr.provider_id, pr.specialty, prov_stats.visit_count;

-- Query 6
WITH EmploymentData AS (
    SELECT patient_id,
           MAX(status_date) AS last_employment_change
    FROM employment_status
    GROUP BY patient_id
),
IncomeStatus AS (
    SELECT patient_id,
           income_level,
           DENSE_RANK() OVER (PARTITION BY patient_id ORDER BY recorded_date DESC) AS rank
    FROM income_brackets
)
SELECT em.patient_id,
       hs.housing_type,
       em.last_employment_change,
       ISNULL(i.income_level, 'Unknown') AS current_income_level
FROM EmploymentData em
JOIN housing_status hs ON em.patient_id = hs.patient_id
LEFT JOIN IncomeStatus i ON em.patient_id = i.patient_id AND i.rank = 1
WHERE hs.status_date > CURRENT_DATE - INTERVAL '1 year';

-- Query 7
WITH ClaimsSummary AS (
    SELECT patient_id,
           SUM(claim_amount) AS total_claimed,
           SUM(paid_amount) AS total_paid
    FROM claims
    GROUP BY patient_id
),
ActivePatients AS (
    SELECT patient_id FROM visits WHERE visit_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
)
SELECT c.patient_id,
       total_claimed,
       total_paid,
       (total_claimed - total_paid) AS balance
FROM ClaimsSummary c
JOIN ActivePatients ap ON c.patient_id = ap.patient_id
HAVING (total_claimed - total_paid) > 1000;

-- Query 8
WITH MaxVisitInfo AS (
    SELECT patient_id, 
           MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
),
CriticalProcedures AS (
    SELECT visit_id,
           procedure_description,
           procedure_date
    FROM procedures
    WHERE procedure_description LIKE '%critical%'
)
SELECT p.patient_id,
       hv.last_visit_date,
       cr_procs.procedure_description,
       COALESCE(a.allergen, 'No Allergy') AS allergen
FROM patients p
JOIN MaxVisitInfo hv ON p.patient_id = hv.patient_id
LEFT JOIN CriticalProcedures cr_procs ON p.patient_id = cr_procs.visit_id
LEFT JOIN allergies a ON p.patient_id = a.patient_id
WHERE cr_procs.procedure_date > CURRENT_DATE - INTERVAL '6 months';

-- Query 9
WITH TopMedications AS (
    SELECT visit_id,
           medication_name,
           ROW_NUMBER() OVER (PARTITION BY visit_id ORDER BY COUNT(*) DESC) AS rnk
    FROM medications
    GROUP BY visit_id, medication_name
),
VisitVitals AS (
    SELECT visit_id,
           MAX(bmi) AS max_bmi
    FROM vitals
    GROUP BY visit_id
)
SELECT v.visit_id,
       tm.medication_name AS most_prescribed,
       vv.max_bmi,
       CASE 
           WHEN vv.max_bmi > 30 THEN 'Obese'
           ELSE 'Healthy'
       END AS bmi_category
FROM visits v
JOIN TopMedications tm ON v.visit_id = tm.visit_id AND tm.rnk = 1
JOIN VisitVitals vv ON v.visit_id = vv.visit_id;

-- Query 10
WITH ImagingSummaries AS (
    SELECT visit_id,
           COUNT(imaging_id) AS imaging_count
    FROM imaging
    WHERE performed_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY visit_id
),
LabFlags AS (
    SELECT visit_id,
           COUNT(CASE WHEN result_flag = 'H' THEN 1 END) AS high_flags
    FROM labs
    GROUP BY visit_id
)
SELECT im.visit_id,
       im.imaging_count,
       lf.high_flags,
       CASE 
           WHEN lf.high_flags > 3 THEN 'Investigate'
           ELSE 'Normal'
       END AS flag_status
FROM ImagingSummaries im
JOIN LabFlags lf ON im.visit_id = lf.visit_id
WHERE im.imaging_count > 2;