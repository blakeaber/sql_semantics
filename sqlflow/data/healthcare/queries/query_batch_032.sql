-- Query 1
WITH RecentVisits AS (
    SELECT visit_id, patient_id, visit_date
    FROM visits
    WHERE visit_date >= CURRENT_DATE - INTERVAL '1 year'
)
SELECT p.patient_id, COUNT(DISTINCT v.visit_id) AS total_visits, 
       AVG(claim_amount) AS avg_claim_amount,
       CASE
           WHEN AVG(claim_amount) > 500 THEN 'High'
           ELSE 'Low'
       END AS claim_category
FROM patients p
INNER JOIN RecentVisits v ON p.patient_id = v.patient_id
LEFT JOIN claims c ON v.visit_id = c.visit_id
GROUP BY p.patient_id
HAVING COUNT(DISTINCT v.visit_id) > 1;

-- Query 2
WITH CommonConditions AS (
    SELECT patient_id, condition_name, COUNT(*) AS condition_count
    FROM conditions
    GROUP BY patient_id, condition_name
    ORDER BY condition_count DESC
)
SELECT p.patient_id, c.condition_name, AVG(b.amount) AS avg_billed
FROM patients p
JOIN CommonConditions c ON p.patient_id = c.patient_id
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN billing b ON cl.claim_id = b.claim_id
GROUP BY p.patient_id, c.condition_name
HAVING AVG(b.amount) > 100;

-- Query 3
WITH ProvidersInfo AS (
    SELECT provider_id, CONCAT(first_name, ' ', last_name) AS provider_full_name
    FROM providers
)
SELECT v.visit_id, pi.provider_full_name, MAX(pro.date) AS last_procedure_date, 
       DENSE_RANK() OVER (ORDER BY MAX(pro.date) DESC) AS procedure_ranking
FROM visits v
JOIN procedures pro ON v.visit_id = pro.visit_id
JOIN ProvidersInfo pi ON v.provider_id = pi.provider_id
GROUP BY v.visit_id, pi.provider_full_name;

-- Query 4
WITH TopMedications AS (
    SELECT medication_name, COUNT(DISTINCT patient_id) AS patient_count
    FROM medications m
    JOIN visits v ON m.visit_id = v.visit_id
    GROUP BY medication_name
    ORDER BY patient_count DESC
    LIMIT 5
)
SELECT tm.medication_name, pt.first_name, pt.last_name, i.payer_name
FROM TopMedications tm
JOIN visits v ON tm.medication_name = v.reason_for_visit
JOIN patients pt ON v.patient_id = pt.patient_id
LEFT JOIN insurance i ON pt.insurance_id = i.insurance_id;

-- Query 5
SELECT p.patient_id, 
       COUNT(DISTINCT e.encounter_type_id) AS number_of_encounter_types,
       SUM(m.amount) AS total_claims, 
       SUBSTRING(REPLACE(i.payer_name, ' ', ''), 1, 5) AS payer_code
FROM patients p
INNER JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN claims c ON v.visit_id = c.visit_id
LEFT JOIN billing m ON c.claim_id = m.claim_id
LEFT JOIN insurance i ON p.insurance_id = i.insurance_id
GROUP BY p.patient_id, i.payer_name;

-- Query 6
WITH VitalsData AS (
    SELECT visit_id, AVG(heart_rate) AS avg_heart_rate
    FROM vitals
    GROUP BY visit_id
)
SELECT v.visit_id, v.location, vi.avg_heart_rate, 
       COALESCE(im.impression, 'No findings') AS imaging_impression
FROM visits v
JOIN VitalsData vi ON v.visit_id = vi.visit_id
LEFT JOIN imaging im ON v.visit_id = im.visit_id;

-- Query 7
SELECT sd.patient_id, sd.sdoh_type, 
       COALESCE(STRING_AGG(e.employer_name, ', ' ORDER BY e.status_date), 'Unemployed') AS employer_history
FROM sdoh_entries sd
LEFT JOIN employment_status e ON sd.patient_id = e.patient_id
GROUP BY sd.patient_id, sd.sdoh_type;

-- Query 8
WITH RiskScores AS (
    SELECT patient_id, score_type, AVG(score_value) AS average_score
    FROM risk_scores
    GROUP BY patient_id, score_type
)
SELECT r.patient_id, r.score_type, r.average_score, 
       CONCAT(a.street_address, ', ', a.city) AS full_address
FROM RiskScores r
JOIN patients p ON r.patient_id = p.patient_id
LEFT JOIN addresses a ON p.address_id = a.address_id;

-- Query 9
SELECT c.patient_id, 
       COUNT(DISTINCT v.visit_id) AS visit_count,
       SUM(v.was_emergency::int) AS emergency_visits,
       STRING_AGG(DISTINCT prov.specialty, ', ') AS provider_specialties
FROM conditions c
JOIN visits v ON c.patient_id = v.patient_id
JOIN providers prov ON v.provider_id = prov.provider_id
GROUP BY c.patient_id
HAVING COUNT(DISTINCT v.visit_id) > 5;

-- Query 10
WITH DiagnosisSummary AS (
    SELECT patient_id, diagnosis_code, COUNT(diagnosis_id) AS diagnosis_count
    FROM diagnoses
    GROUP BY patient_id, diagnosis_code
)
SELECT ds.patient_id, ds.diagnosis_code, ds.diagnosis_count, 
       FLOOR(SUM(cl.billed_amount) / COUNT(cl.claim_id)) AS avg_billed_per_claim
FROM DiagnosisSummary ds
JOIN claims cl ON ds.patient_id = cl.patient_id
GROUP BY ds.patient_id, ds.diagnosis_code;