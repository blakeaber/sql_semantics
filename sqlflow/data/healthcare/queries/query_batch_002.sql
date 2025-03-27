-- Query 1
WITH recent_visits AS (
    SELECT visit_id, patient_id, visit_date, location
    FROM visits
    WHERE visit_date >= NOW() - INTERVAL '30 days'
),
provider_specialties AS (
    SELECT provider_id, specialty
    FROM providers
)
SELECT p.first_name, p.last_name, v.visit_date, v.location,
       ps.specialty AS provider_specialty,
       COUNT(d.diagnosis_id) AS diagnosis_count,
       SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) OVER (PARTITION BY p.patient_id) AS emergency_count
FROM patients p
JOIN recent_visits v ON p.patient_id = v.patient_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN (
    SELECT visit_id, MAX(admission_time) AS max_admission
    FROM visits
    GROUP BY visit_id
) recent_admissions ON recent_admissions.visit_id = v.visit_id
LEFT JOIN provider_specialties ps ON v.provider_id = ps.provider_id
WHERE p.gender = 'Female'
GROUP BY p.patient_id, v.visit_date, v.location, ps.specialty
HAVING COUNT(d.diagnosis_id) > 0
ORDER BY p.last_name, v.visit_date;

-- Query 2
WITH med_usage AS (
    SELECT visit_id, COUNT(medication_id) AS medication_count
    FROM medications
    GROUP BY visit_id
)
SELECT p.patient_id, p.first_name, p.last_name,
       SUM(c.paid_amount) AS total_paid, ns.symptom_count
FROM patients p
JOIN claims c ON p.patient_id = c.patient_id
JOIN (
    SELECT visit_id, COUNT(symptom_id) AS symptom_count
    FROM symptoms
    GROUP BY visit_id
) ns ON c.visit_id = ns.visit_id
JOIN med_usage mu ON c.visit_id = mu.visit_id
WHERE ns.symptom_count > 3
GROUP BY p.patient_id, ns.symptom_count
HAVING SUM(c.paid_amount) > 1000
ORDER BY total_paid DESC;

-- Query 3
WITH patient_housing AS (
    SELECT patient_id, COUNT(housing_id) AS housing_changes
    FROM housing_status
    GROUP BY patient_id
),
latest_labs AS (
    SELECT visit_id, MAX(reported_date) AS last_report
    FROM labs
    GROUP BY visit_id
)
SELECT p.first_name, p.last_name, h.housing_changes, ll.last_report,
       COUNT(DISTINCT i.imaging_id) AS imaging_count
FROM patients p
JOIN patient_housing h ON p.patient_id = h.patient_id
LEFT JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN latest_labs ll ON v.visit_id = ll.visit_id
JOIN imaging i ON v.visit_id = i.visit_id
GROUP BY p.patient_id, h.housing_changes, ll.last_report
HAVING COUNT(i.imaging_id) > 2
ORDER BY h.housing_changes DESC;

-- Query 4
WITH high_risk_patients AS (
    SELECT patient_id, AVG(score_value) AS avg_risk
    FROM risk_scores
    GROUP BY patient_id
    HAVING AVG(score_value) > 75
),
race_summary AS (
    SELECT r.race_ethnicity_name, COUNT(DISTINCT p.patient_id) AS total_patients
    FROM race_ethnicity r
    JOIN patients p ON r.race_ethnicity_id = p.race_ethnicity_id
    GROUP BY r.race_ethnicity_name
)
SELECT hrp.patient_id, p.first_name, p.last_name,
       rs.race_ethnicity_name, hrp.avg_risk,
       SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visits
FROM high_risk_patients hrp
JOIN patients p ON hrp.patient_id = p.patient_id
JOIN race_summary rs ON p.race_ethnicity_id = rs.race_ethnicity_name
JOIN visits v ON p.patient_id = v.patient_id
GROUP BY hrp.patient_id, rs.race_ethnicity_name, hrp.avg_risk
ORDER BY hrp.avg_risk DESC;

-- Query 5
WITH language_patients AS (
    SELECT patient_id, l.language_name
    FROM patients p
    JOIN languages l ON p.language_id = l.language_id
),
provider_encounters AS (
    SELECT provider_id, COUNT(encounter_type_id) AS encounter_count
    FROM visits
    GROUP BY provider_id
)
SELECT lp.language_name, pe.encounter_count, COUNT(DISTINCT v.visit_id) AS total_visits
FROM language_patients lp
JOIN visits v ON lp.patient_id = v.patient_id
JOIN provider_encounters pe ON v.provider_id = pe.provider_id
JOIN (
    SELECT visit_id, AVG(result_value) AS avg_lab_value
    FROM labs
    GROUP BY visit_id
) lv ON v.visit_id = lv.visit_id
WHERE lv.avg_lab_value > 5.0
GROUP BY lp.language_name, pe.encounter_count
ORDER BY total_visits DESC;

-- Query 6
WITH recent_claims AS (
    SELECT claim_id, visit_id, paid_amount
    FROM claims
    WHERE claim_date > NOW() - INTERVAL '6 months'
),
billing_details AS (
    SELECT claim_id, amount
    FROM billing
)
SELECT p.patient_id, p.first_name, p.last_name,
       b.amount AS billed, rc.paid_amount,
       CASE
           WHEN rc.paid_amount > b.amount THEN 'Overpaid'
           ELSE 'Underpaid'
       END AS payment_status
FROM patients p
JOIN recent_claims rc ON p.patient_id = rc.patient_id
JOIN billing_details b ON rc.claim_id = b.claim_id
GROUP BY p.patient_id, b.amount, rc.paid_amount
ORDER BY rc.paid_amount DESC;

-- Query 7
WITH patient_conditions AS (
    SELECT patient_id, condition_name, MAX(diagnosed_date) AS last_diagnosed
    FROM conditions
    GROUP BY patient_id, condition_name
),
provider_notes AS (
    SELECT provider_id, COUNT(note_id) AS note_count
    FROM clinical_notes
    GROUP BY provider_id
)
SELECT pc.patient_id, pc.condition_name, pn.note_count, pc.last_diagnosed,
       COUNT(DISTINCT vi.visit_id) AS visit_count
FROM patient_conditions pc
JOIN visits vi ON pc.patient_id = vi.patient_id
JOIN provider_notes pn ON vi.provider_id = pn.provider_id
JOIN (
    SELECT procedure_id, procedure_code
    FROM procedures
    WHERE EXTRACT(MONTH FROM procedure_date) = EXTRACT(MONTH FROM NOW())
) pr ON vi.visit_id = pr.visit_id
GROUP BY pc.patient_id, pc.condition_name, pn.note_count, pc.last_diagnosed
ORDER BY pc.last_diagnosed DESC;

-- Query 8
WITH long_stay_patients AS (
    SELECT patient_id, AVG(discharge_time - admission_time) AS avg_stay
    FROM visits
    GROUP BY patient_id
    HAVING AVG(discharge_time - admission_time) > INTERVAL '3 days'
),
insurance_summary AS (
    SELECT insurance_id, COUNT(member_id) AS member_count
    FROM insurance
    WHERE expiration_date > NOW()
    GROUP BY insurance_id
)
SELECT lsp.patient_id, p.first_name, p.last_name,
       MIN(v.visit_date) AS first_long_stay_date,
       is.member_count AS total_members
FROM long_stay_patients lsp
JOIN patients p ON lsp.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN insurance_summary is ON p.insurance_id = is.insurance_id
GROUP BY lsp.patient_id, is.member_count
ORDER BY total_members DESC;

-- Query 9
WITH symptom_summary AS (
    SELECT visit_id, COUNT(symptom_id) AS symptom_count
    FROM symptoms
    GROUP BY visit_id
),
procedure_details AS (
    SELECT visit_id, MAX(procedure_date) AS last_procedure
    FROM procedures
    GROUP BY visit_id
)
SELECT pr.visit_id, COUNT(DISTINCT d.diagnosis_id) AS diagnosis_count,
       ss.symptom_count, pr.last_procedure
FROM procedure_details pr
JOIN visits v ON pr.visit_id = v.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN symptom_summary ss ON v.visit_id = ss.visit_id
LEFT JOIN (
    SELECT visit_id, SUM(billed_amount) AS total_billed
    FROM claims
    GROUP BY visit_id
) cb ON v.visit_id = cb.visit_id
WHERE cb.total_billed > 500
GROUP BY pr.visit_id, ss.symptom_count, pr.last_procedure
ORDER BY diagnosis_count DESC;

-- Query 10
WITH income_brackets_summary AS (
    SELECT patient_id, MIN(income_level) AS min_income
    FROM income_brackets
    GROUP BY patient_id
),
visit_analysis AS (
    SELECT visit_id, was_emergency, COUNT(procedure_id) AS procedure_count
    FROM visits v
    LEFT JOIN procedures p ON v.visit_id = p.visit_id
    WHERE v.location IN ('Hospital A', 'Hospital B')
    GROUP BY v.visit_id
)
SELECT p.patient_id, p.first_name, p.last_name,
       ibs.min_income, va.procedure_count
FROM income_brackets_summary ibs
JOIN patients p ON ibs.patient_id = p.patient_id
JOIN visit_analysis va ON p.patient_id = va.patient_id
JOIN (
    SELECT medication_id, COUNT(medication_code) AS med_code_count
    FROM medications
    GROUP BY medication_id
) mc ON va.visit_id = mc.medication_id
WHERE mc.med_code_count > 2
GROUP BY p.patient_id, ibs.min_income, va.procedure_count
HAVING va.procedure_count > 1
ORDER BY va.procedure_count DESC;