-- Query 1
WITH recent_visits AS (
    SELECT visit_id, MAX(visit_date) AS latest_visit
    FROM visits
    GROUP BY visit_id
)
SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    COUNT(v.visit_id) AS total_visits,
    AVG(pb.billed_amount) AS avg_billed_amount,
    CASE 
        WHEN COUNT(distinct d.diagnosis_id) > 5 THEN 'High'
        ELSE 'Low'
    END AS diagnosis_risk
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN billing b ON v.visit_id = b.claim_id
JOIN recent_visits rv ON v.visit_id = rv.visit_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING AVG(b.billed_amount) > 1000
ORDER BY total_visits DESC;

-- Query 2
WITH vital_avg AS (
    SELECT visit_id, AVG(bmi) AS avg_bmi FROM vitals GROUP BY visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COUNT(ic.income_id) AS income_bracket_count,
    vit.avg_bmi,
    SUM(dosage::FLOAT) AS total_medication_dosage
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN income_brackets ic ON p.patient_id = ic.patient_id
JOIN (
    SELECT visit_id, SUM(dosage::FLOAT) AS dosage
    FROM medications 
    GROUP BY visit_id
) m ON v.visit_id = m.visit_id
LEFT JOIN vital_avg vit ON v.visit_id = vit.visit_id
WHERE vit.avg_bmi > 25
GROUP BY p.patient_id, p.first_name, p.last_name, vit.avg_bmi;

-- Query 3
WITH recent_claims AS (
    SELECT patient_id, MAX(claim_date) AS recent_claim_date
    FROM claims
    GROUP BY patient_id
)
SELECT 
    pr.provider_id,
    pr.first_name AS provider_first_name,
    pr.last_name AS provider_last_name,
    COUNT(v.visit_id) AS visit_count,
    MAX(v.admission_time) AS last_admission_time,
    STRING_AGG(d.diagnosis_code, ', ') AS diagnosis_codes
FROM providers pr
JOIN visits v ON pr.provider_id = v.provider_id
JOIN diagnostics d ON v.visit_id = d.visit_id
JOIN recent_claims rc ON v.patient_id = rc.patient_id
WHERE v.was_emergency = TRUE AND rc.recent_claim_date > '2023-01-01'
GROUP BY pr.provider_id, pr.first_name, pr.last_name;

-- Query 4
WITH language_count AS (
    SELECT language_id, COUNT(patient_id) AS patient_count
    FROM patients
    GROUP BY language_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    l.language_name,
    lc.patient_count,
    CASE 
        WHEN lenim.pressure_systolic > 140 THEN 'High' 
        ELSE 'Normal' 
    END AS bp_status,
    SUM(s.survey_score) AS total_survey_score
FROM patients p
JOIN languages l ON p.language_id = l.language_id
JOIN language_count lc ON p.language_id = lc.language_id
JOIN vitals v ON p.patient_id = v.visit_id
JOIN surveys s ON p.patient_id = s.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, l.language_name, v.blood_pressure_systolic;

-- Query 5
WITH freq_visits AS (
    SELECT patient_id, COUNT(visit_id) AS visit_count
    FROM visits
    GROUP BY patient_id
    HAVING visit_count > 5
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    f.visit_count,
    MIN(c.claim_amount) AS min_claim_amount,
    CASE
        WHEN MAX(prv.paid_amount) > 500 THEN 'High' 
        ELSE 'Low' 
    END AS payment_status
FROM patients p
JOIN freq_visits f ON p.patient_id = f.patient_id
JOIN claims c ON p.patient_id = c.patient_id
JOIN payments prv ON c.claim_id = prv.claim_id
GROUP BY p.patient_id, p.first_name, p.last_name, f.visit_count;

-- Query 6
WITH recent_diagnosis AS (
    SELECT patient_id, MAX(diagnosis_date) AS last_diagnosis_date
    FROM diagnoses
    GROUP BY patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COALESCE(SUM(lab.result_value), 0) AS total_lab_results,
    COUNT(distinct pr.procedure_id) AS procedure_count,
    rec.last_diagnosis_date
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN procedures pr ON v.visit_id = pr.visit_id
JOIN labs lab ON v.visit_id = lab.visit_id
LEFT JOIN recent_diagnosis rec ON p.patient_id = rec.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, rec.last_diagnosis_date 
HAVING COALESCE(SUM(lab.result_value), 0) > 0;

-- Query 7
WITH patient_conditions AS (
    SELECT 
        patient_id, 
        condition_name, 
        DENSE_RANK() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) as rank
    FROM conditions
)
SELECT 
    p.patient_id,
    p.first_name,
    ENUM.aff_list AS allergies
FROM patients p
LEFT JOIN (
    SELECT patient_id, ARRAY_AGG(allergen) AS aff_list
    FROM allergies
    GROUP BY patient_id
) ENUM ON p.patient_id = ENUM.patient_id
JOIN patient_conditions pc ON p.patient_id = pc.patient_id AND pc.rank = 1
WHERE pc.condition_name IN ('Diabetes', 'Hypertension');

-- Query 8
WITH latest_employment AS (
    SELECT patient_id, employment_type, MAX(status_date) AS recent_date
    FROM employment_status
    GROUP BY patient_id, employment_type
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    emp.employment_type,
    MAX(visit.visit_date) AS last_visit_date,
    CASE
        WHEN AVG(vital.bmi) > 30 THEN 'Obese' 
        ELSE 'Not Obese' 
    END AS obesity_status
FROM patients p
JOIN visits visit ON p.patient_id = visit.patient_id
JOIN vitals vital ON vital.visit_id = visit.visit_id
JOIN latest_employment emp ON p.patient_id = emp.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, emp.employment_type;

-- Query 9
WITH housing_stability AS (
    SELECT patient_id, DATEDIFF(year, MIN(status_date), MAX(status_date)) AS years_stable
    FROM housing_status
    GROUP BY patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    hs.years_stable,
    SUM(payment.amount) AS total_payments,
    COUNT(DISTINCT sd.sdoh_type) AS diverse_sdoh_entries
FROM patients p
JOIN housing_stability hs ON p.patient_id = hs.patient_id
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN payments payment ON cl.claim_id = payment.claim_id
LEFT JOIN sdoh_entries sd ON p.patient_id = sd.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, hs.years_stable;

-- Query 10
WITH monthly_diagnosis_count AS (
    SELECT patient_id, COUNT(diagnosis_id) AS monthly_count, DATE_TRUNC('month', diagnosis_date) AS diag_month
    FROM diagnoses
    GROUP BY patient_id, DATE_TRUNC('month', diagnosis_date)
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    diag_count.monthly_count,
    COALESCE(MAX(bill.billed_amount), 0) AS max_billed_amount,
    CASE
        WHEN COALESCE(MIN(survey.survey_score), 0) < 50 THEN 'At Risk'
        ELSE 'Stable'
    END AS risk_level
FROM patients p
JOIN monthly_diagnosis_count diag_count ON p.patient_id = diag_count.patient_id
LEFT JOIN billing bill ON p.patient_id = bill.claim_id
LEFT JOIN surveys survey ON p.patient_id = survey.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, diag_count.monthly_count;