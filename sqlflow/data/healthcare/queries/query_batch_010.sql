-- Query 1
WITH recent_visits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)
SELECT p.patient_id, p.gender, p.date_of_birth,
       AVG(CASE WHEN vs.was_emergency THEN 1 ELSE 0 END) OVER (PARTITION BY p.gender) AS avg_emergency_visits
FROM patients p
JOIN recent_visits rv ON p.patient_id = rv.patient_id
JOIN visits vs ON rv.patient_id = vs.patient_id
JOIN (
    SELECT visit_id
    FROM diagnoses
    WHERE diagnosis_code IN (
        SELECT DISTINCT diagnosis_code
        FROM diagnoses
        WHERE diagnosis_date > CURRENT_DATE - INTERVAL '1 year'
    )
) AS diag ON vs.visit_id = diag.visit_id
WHERE vs.visit_date = rv.last_visit_date
GROUP BY p.patient_id, p.gender, p.date_of_birth
HAVING COUNT(vs.visit_id) > 2;

-- Query 2
WITH visit_counts AS (
    SELECT provider_id, COUNT(visit_id) AS num_visits
    FROM visits
    GROUP BY provider_id
)
SELECT pr.provider_id, pr.first_name || ' ' || pr.last_name AS provider_full_name,
       PR.specialty, AVG(ic.bmi) AS avg_bmi,
       DENSE_RANK() OVER (ORDER BY SUM(vs.billed_amount) DESC) AS billing_rank
FROM providers pr
JOIN visit_counts vc ON pr.provider_id = vc.provider_id
JOIN visits vs ON pr.provider_id = vs.provider_id
JOIN vitals ic ON vs.visit_id = ic.visit_id
JOIN (
    SELECT claim_id, billed_amount
    FROM claims
    WHERE claim_status = 'PAID'
) AS c ON vs.visit_id = c.visit_id
WHERE vc.num_visits > 10
GROUP BY pr.provider_id, pr.first_name, pr.last_name, pr.specialty;

-- Query 3
WITH high_risk_patients AS (
    SELECT patient_id, MAX(score_value) AS max_risk_score
    FROM risk_scores
    WHERE score_value > 70
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, COALESCE(l.language_name, 'Unknown') AS language,
       AVG(lr.result_value) AS avg_lab_result,
       SUM(
           CASE 
           WHEN ic.income_level = 'High' THEN 1 
           ELSE 0 END
       ) AS high_income_count
FROM patients p
JOIN high_risk_patients hrp ON p.patient_id = hrp.patient_id
LEFT JOIN languages l ON p.language_id = l.language_id
JOIN visits vs ON p.patient_id = vs.patient_id
JOIN labs lr ON vs.visit_id = lr.visit_id
LEFT JOIN income_brackets ic ON p.patient_id = ic.patient_id
GROUP BY p.first_name, p.last_name, l.language_name
ORDER BY AVG(lr.result_value) DESC;

-- Query 4
WITH active_conditions AS (
    SELECT patient_id, condition_name
    FROM conditions
    WHERE condition_status = 'Active'
)
SELECT p.patient_id, p.date_of_birth, 
       COUNT(distinct s.survey_id) AS survey_count,
       ROUND(AVG(sc.survey_score)::numeric, 2) AS avg_survey_score,
       COUNT(distinct et.encounter_type_id) AS encounter_type_variety
FROM patients p
JOIN active_conditions ac ON p.patient_id = ac.patient_id
LEFT JOIN surveys s ON p.patient_id = s.patient_id
LEFT JOIN screenings sc ON p.patient_id = sc.patient_id
JOIN visits vs ON p.patient_id = vs.patient_id
JOIN encounter_types et ON vs.encounter_type_id = et.encounter_type_id
WHERE vs.visit_date > p.created_at
GROUP BY p.patient_id, p.date_of_birth
HAVING COUNT(ac.condition_name) > 1;

-- Query 5
SELECT v.visit_id,
       v.location,
       ROW_NUMBER() OVER (PARTITION BY v.location ORDER BY v.admission_time) AS location_rank,
       CASE 
       WHEN EXTRACT(HOUR FROM v.admission_time) BETWEEN 8 AND 16 THEN 'Daytime'
       ELSE 'Nighttime'
       END AS visit_period,
       SUM(pg.amount) AS total_payment
FROM visits v
JOIN procedures pc ON v.visit_id = pc.visit_id
LEFT JOIN (
    SELECT b.claim_id, b.amount
    FROM billing b
    JOIN claims c ON b.claim_id = c.claim_id
    WHERE c.claim_status = 'PAID'
) AS pg ON v.visit_id = pg.claim_id
WHERE v.was_emergency = true
GROUP BY v.visit_id, v.location, v.admission_time
ORDER BY total_payment DESC;

-- Query 6
WITH emergency_visits AS (
    SELECT visit_id
    FROM visits
    WHERE was_emergency = true
)
SELECT DISTINCT p.first_name, p.last_name,
       COUNT(et.encounter_type_id) AS encounter_count,
       SUM(
           CASE 
           WHEN EXTRACT(YEAR FROM vs.visit_date) = 2023 THEN 1
           ELSE 0 END
       ) AS visits_2023
FROM patients p
JOIN emergency_visits ev ON p.patient_id = ev.visit_id
LEFT JOIN visits vs ON ev.visit_id = vs.visit_id
LEFT JOIN encounter_types et ON vs.encounter_type_id = et.encounter_type_id
WHERE p.date_of_birth < '2000-01-01'
GROUP BY p.first_name, p.last_name
HAVING encounter_count > 5;

-- Query 7
WITH recent_imaging AS (
    SELECT visit_id, MAX(performed_date) AS last_imaging_date
    FROM imaging
    GROUP BY visit_id
)
SELECT p.first_name, p.last_name, sd.sdoh_type, h.housing_type,
       LAG(vs.visit_date) OVER (PARTITION BY im.imaging_type ORDER BY vs.visit_date) AS previous_visit_date
FROM patients p
JOIN sdoh_entries sd ON p.patient_id = sd.patient_id
LEFT JOIN housing_status h ON p.patient_id = h.patient_id
JOIN visits vs ON p.patient_id = vs.patient_id
JOIN recent_imaging rim ON vs.visit_id = rim.visit_id
JOIN imaging im ON rim.visit_id = im.visit_id
WHERE im.findings IS NOT NULL
ORDER BY p.last_name, p.first_name;

-- Query 8
WITH medication_use AS (
    SELECT visit_id, MAX(start_date) AS most_recent_start
    FROM medications
    GROUP BY visit_id
)
SELECT p.patient_id, count(med.medication_id) AS medication_count,
       MAX(claim.claim_amount) AS max_claim_amount,
       COUNT(DISTINCT pr.provider_id) AS distinct_providers
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN medication_use mu ON v.visit_id = mu.visit_id
LEFT JOIN medications med ON mu.visit_id = med.visit_id
LEFT JOIN claims claim ON v.visit_id = claim.visit_id
LEFT JOIN providers pr ON v.provider_id = pr.provider_id
WHERE claim.claim_status = 'Submitted'
GROUP BY p.patient_id
HAVING medication_count > 2;

-- Query 9
SELECT p.first_name, p.last_name,
       CASE 
       WHEN rs.result_value > 100 THEN 'High Risk'
       WHEN rs.result_value BETWEEN 50 AND 100 THEN 'Medium Risk'
       ELSE 'Low Risk'
       END AS risk_category,
       SUM(
           CASE 
           WHEN em.employment_type = 'Employed' THEN 1
           ELSE 0 END
       ) AS employed_count
FROM patients p
JOIN risk_scores rs ON p.patient_id = rs.patient_id
LEFT JOIN employment_status em ON p.patient_id = em.patient_id
JOIN visits vs ON p.patient_id = vs.patient_id
LEFT JOIN (
    SELECT visit_id
    FROM imaging
    WHERE imaging_type = 'MRI'
) AS img ON vs.visit_id = img.visit_id
GROUP BY p.first_name, p.last_name, rs.result_value;

-- Query 10
WITH recent_conditions AS (
    SELECT patient_id, MAX(diagnosed_date) AS last_diagnosed
    FROM conditions
    GROUP BY patient_id
)
SELECT a.street_address, a.city, a.postal_code,
       ROUND(AVG(co.condition_id)::numeric, 2) AS avg_condition_id,
       SUM(
           CASE 
           WHEN vs.encounter_type_id IN (
               SELECT encounter_type_id 
               FROM encounter_types 
               WHERE encounter_type_name LIKE '%surgery%'
           ) THEN 1
           ELSE 0 END
       ) AS surgery_count
FROM addresses a
JOIN patients p ON a.address_id = p.address_id
JOIN recent_conditions rc ON p.patient_id = rc.patient_id
LEFT JOIN conditions co ON rc.patient_id = co.patient_id
LEFT JOIN visits vs ON co.condition_id = vs.visit_id
WHERE vs.visit_date BETWEEN rc.last_diagnosed - INTERVAL '1 year' AND rc.last_diagnosed
GROUP BY a.street_address, a.city, a.postal_code;