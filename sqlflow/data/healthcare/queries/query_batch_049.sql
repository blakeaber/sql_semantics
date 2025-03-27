
WITH TotalVisits AS (
    SELECT p.patient_id, COUNT(v.visit_id) AS visit_count
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    GROUP BY p.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, rt.race_ethnicity_name,
    CASE 
        WHEN visit_count > 10 THEN 'High'
        ELSE 'Low'
    END AS visit_frequency,
    AVG(cl.paid_amount) OVER (PARTITION BY v.provider_id) AS avg_paid_per_provider
FROM patients p
JOIN TotalVisits tv ON p.patient_id = tv.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN race_ethnicity rt ON p.race_ethnicity_id = rt.race_ethnicity_id
JOIN claims cl ON v.visit_id = cl.visit_id
WHERE tv.visit_count > 0
AND p.created_at IN (
    SELECT MAX(created_at) 
    FROM patients 
    GROUP BY gender
)
ORDER BY visit_frequency DESC;


WITH ProviderProcedures AS (
    SELECT p.provider_id, COUNT(proc.procedure_id) AS procedure_count
    FROM procedures proc
    JOIN visits v ON proc.visit_id = v.visit_id
    JOIN providers p ON v.provider_id = p.provider_id
    GROUP BY p.provider_id
)
SELECT proc.procedure_description, prov.first_name || ' ' || prov.last_name AS provider_name,
    pp.procedure_count,
    ROW_NUMBER() OVER (PARTITION BY enc.encounter_type_name ORDER BY proc.procedure_date) AS procedure_rank
FROM procedures proc
JOIN visits v ON proc.visit_id = v.visit_id
JOIN providers prov ON v.provider_id = prov.provider_id
JOIN encounter_types enc ON v.encounter_type_id = enc.encounter_type_id
JOIN ProviderProcedures pp ON prov.provider_id = pp.provider_id
WHERE pp.procedure_count > 5
AND proc.procedure_date >= ALL (
    SELECT p.proc_date 
    FROM procedures p 
    WHERE p.visit_id = proc.visit_id
)
HAVING COUNT(proc.procedure_id) > 1;


WITH AllergySeverity AS (
    SELECT patient_id, MAX(severity) AS max_severity
    FROM allergies
    GROUP BY patient_id
)
SELECT p.patient_id, a.allergen, asv.max_severity, COUNT(v.visit_id) AS total_visits,
    COALESCE(NULLIF(rt.race_ethnicity_name, ''), 'Unknown') AS race_ethnicity
FROM allergies a
JOIN patients p ON a.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN race_ethnicity rt ON p.race_ethnicity_id = rt.race_ethnicity_id
JOIN AllergySeverity asv ON p.patient_id = asv.patient_id
LEFT JOIN (
    SELECT vs.visit_id, SUM(vs.weight_kg) AS total_weight
    FROM vitals vs
    GROUP BY vs.visit_id
) vw ON v.visit_id = vw.visit_id
WHERE a.recorded_date IN (
    SELECT MIN(recorded_date)
    FROM allergies
    GROUP BY allergen
)
ORDER BY total_visits DESC;


WITH MedicationFrequency AS (
    SELECT medication_name, COUNT(*) AS freq
    FROM medications
    GROUP BY medication_name
)
SELECT m.medication_name, mf.freq, sd.description, sd.recorded_date,
    DENSE_RANK() OVER (ORDER BY mf.freq DESC) AS rank_by_frequency
FROM medications m
JOIN visits v ON m.visit_id = v.visit_id
JOIN sdoh_entries sd ON v.patient_id = sd.patient_id
JOIN (
    SELECT v.visit_id, COUNT(d.diagnosis_id) AS num_diagnoses
    FROM diagnoses d
    JOIN visits v ON d.visit_id = v.visit_id
    GROUP BY v.visit_id
) diag ON v.visit_id = diag.visit_id
JOIN MedicationFrequency mf ON m.medication_name = mf.medication_name
WHERE diag.num_diagnoses > 3
AND v.visit_date BETWEEN '2020-01-01' AND '2022-01-01'
ORDER BY rank_by_frequency;


WITH AvgBMIPerRace AS (
    SELECT r.race_ethnicity_name, AVG(vt.bmi) AS avg_bmi
    FROM patients p
    JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
    JOIN visits v ON p.patient_id = v.patient_id
    JOIN vitals vt ON v.visit_id = vt.visit_id
    GROUP BY r.race_ethnicity_name
)
SELECT v.visit_id, d.diagnosis_description, vt.bmi, abr.avg_bmi,
    CASE 
        WHEN vt.bmi > abr.avg_bmi THEN 'Above Average'
        ELSE 'Below Average'
    END AS bmi_status
FROM visits v
JOIN vitals vt ON v.visit_id = vt.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN AvgBMIPerRace abr ON abr.race_ethnicity_name = (
    SELECT race_ethnicity_name
    FROM patients p
    JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
    WHERE p.patient_id = v.patient_id
)
WHERE d.diagnosis_date BETWEEN '2021-01-01' AND '2023-01-01'
AND v.location IN (
    SELECT loc.location
    FROM providers p
    JOIN locations loc ON p.provider_id = loc.provider_id
)
ORDER BY bmi_status;


WITH ClaimDetails AS (
    SELECT c.patient_id, SUM(c.paid_amount) AS total_paid, COUNT(c.claim_id) AS num_claims
    FROM claims c
    GROUP BY c.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, ins.plan_type, cd.total_paid,
    CASE
        WHEN num_claims > 5 THEN 'Frequent'
        ELSE 'Infrequent'
    END AS claim_frequency
FROM patients p
JOIN ClaimDetails cd ON p.patient_id = cd.patient_id
JOIN insurance ins ON p.insurance_id = ins.insurance_id
LEFT JOIN surveys s ON p.patient_id = s.patient_id
WHERE ins.expiration_date IN (
    SELECT MAX(expiration_date)
    FROM insurance
    GROUP BY plan_type
)
AND NOT EXISTS (
    SELECT 1 
    FROM employment_status es 
    WHERE es.patient_id = p.patient_id
    AND es.employment_type = 'Unemployed'
)
ORDER BY total_paid DESC;


WITH IncomePerPatient AS (
    SELECT i.patient_id, SUM(i.income_level) AS total_income
    FROM income_brackets i
    GROUP BY i.patient_id
)
SELECT i.patient_id, hs.housing_type, ip.total_income, sc.survey_score,
    NTILE(4) OVER (ORDER BY ip.total_income) AS income_quartile
FROM income_brackets i
JOIN housing_status hs ON i.patient_id = hs.patient_id
JOIN IncomePerPatient ip ON i.patient_id = ip.patient_id
JOIN surveys sc ON i.patient_id = sc.patient_id
LEFT JOIN (
    SELECT e.patient_id, MAX(es.status_date) AS latest_status_date
    FROM employment_status es
    GROUP BY e.patient_id
) emp ON i.patient_id = emp.patient_id
WHERE ip.total_income > 0
AND hs.housing_type IN (
    SELECT housing_type
    FROM housing_status
    WHERE status_date >= '2020-01-01'
)
ORDER BY income_quartile;


WITH VitalsDetails AS (
    SELECT v.visit_id, COUNT(vt.vital_id) AS vital_count, AVG(vt.temperature_c) AS avg_temp
    FROM visits v
    JOIN vitals vt ON v.visit_id = vt.visit_id
    GROUP BY v.visit_id
)
SELECT v.visit_date, vt.heart_rate, vt.respiratory_rate, vd.avg_temp,
    SUM(em.amount) OVER (PARTITION BY v.provider_id) AS total_payment,
    LENGTH('Note: ' || cn.note_text) AS note_length
FROM visits v
JOIN vitals vt ON v.visit_id = vt.visit_id
JOIN VitalsDetails vd ON v.visit_id = vd.visit_id
JOIN clinical_notes cn ON v.visit_id = cn.visit_id
LEFT JOIN payments em ON em.claim_id = (
    SELECT claim_id
    FROM claims c
    WHERE c.visit_id = v.visit_id
    ORDER BY c.claim_date DESC
    LIMIT 1
)
WHERE vd.vital_count > 2
AND v.was_emergency = TRUE
AND vt.blood_pressure_diastolic IN (
    SELECT MIN(blood_pressure_diastolic)
    FROM vitals
    WHERE recorded_at BETWEEN '2021-01-01' AND '2022-01-01'
)
ORDER BY total_payment;


WITH LabFindings AS (
    SELECT lr.test_name, COUNT(lr.lab_result_id) AS num_results
    FROM labs lr
    GROUP BY lr.test_name
)
SELECT l.visit_id, l.findings, lf.num_results,
    COALESCE(NULLIF(ps.provider_name, ''), 'No Provider') AS provider_name,
    CONCAT('Impression: ', img.impression) AS full_impression
FROM imaging img
JOIN visits v ON img.visit_id = v.visit_id
JOIN LabFindings lf ON img.imaging_type = lf.test_name
LEFT JOIN (
    SELECT p.provider_id, p.first_name || ' ' || p.last_name AS provider_name
    FROM providers p
) ps ON v.provider_id = ps.provider_id
WHERE img.performed_date BETWEEN '2020-01-01' AND '2023-01-01'
AND img.body_part NOT IN ('Head', 'Leg')
UNION ALL
SELECT img.visit_id, img.findings, NULL, 'Unknown', 'No Impression'
FROM imaging img
WHERE img.body_part = 'Head';


WITH HeartRateAnalysis AS (
    SELECT visit_id, PERCENT_RANK() OVER (ORDER BY heart_rate) AS heart_rate_rank
    FROM vitals
)
SELECT vt.visit_id, vt.heart_rate, ha.heart_rate_rank,
    CASE
        WHEN heart_rate_rank < 0.5 THEN 'Below Median'
        ELSE 'Above Median'
    END AS heart_rate_category,
    CONCAT(spr.survey_type, ': ', spr.survey_score) AS survey_details
FROM vitals vt
JOIN HeartRateAnalysis ha ON vt.visit_id = ha.visit_id
JOIN visits v ON vt.visit_id = v.visit_id
LEFT JOIN surveys spr ON v.patient_id = spr.patient_id
WHERE vt.recorded_at IN (
    SELECT MAX(recorded_at)
    FROM vitals
    GROUP BY visit_id
)
AND EXISTS (
    SELECT 1 
    FROM screening sc 
    WHERE sc.patient_id = v.patient_id 
    AND sc.screening_type = 'Blood Pressure'
)
ORDER BY heart_rate_category;