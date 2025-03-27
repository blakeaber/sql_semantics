-- Query 1
WITH recent_visits AS (
    SELECT v.patient_id, MAX(v.visit_date) AS last_visit
    FROM visits v
    GROUP BY v.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, v.visit_id, v.encounter_type_id, et.encounter_type_name,
    MAX(v.visit_date) OVER (PARTITION BY p.patient_id) AS most_recent_visit, 
    CASE 
        WHEN v.was_emergency THEN 'Emergency'
        ELSE 'Non-Emergency'
    END AS visit_type
FROM patients p
JOIN recent_visits rv ON p.patient_id = rv.patient_id
JOIN visits v ON rv.patient_id = v.patient_id AND rv.last_visit = v.visit_date
JOIN encounter_types et ON v.encounter_type_id = et.encounter_type_id
JOIN (
    SELECT DISTINCT claim_id, visit_id FROM claims
) c ON v.visit_id = c.visit_id
JOIN (
    SELECT DISTINCT symptom_id, visit_id FROM symptoms WHERE severity = 'Severe'
) s ON v.visit_id = s.visit_id
WHERE p.gender = 'Female';

-- Query 2
WITH avg_billing AS (
    SELECT c.patient_id, AVG(b.amount) AS avg_bill
    FROM claims c
    JOIN billing b ON c.claim_id = b.claim_id
    GROUP BY c.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, i.payer_name,
    avg_billing.avg_bill, 
    COUNT(DISTINCT v.visit_id) AS total_visits,
    SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visits
FROM patients p
JOIN insurance i ON p.insurance_id = i.insurance_id
LEFT JOIN visits v ON p.patient_id = v.patient_id
JOIN avg_billing ON p.patient_id = avg_billing.patient_id
JOIN (SELECT patient_id FROM sdoh_entries WHERE sdoh_type = 'Housing Instability') sdoh ON p.patient_id = sdoh.patient_id
JOIN (
    SELECT DISTINCT hs.patient_id FROM housing_status hs JOIN employment_status es ON hs.patient_id = es.patient_id
) he ON p.patient_id = he.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, i.payer_name, avg_billing.avg_bill
HAVING COUNT(DISTINCT v.visit_id) > 2;

-- Query 3
WITH total_diagnoses AS (
    SELECT v.visit_id, COUNT(d.diagnosis_id) AS diagnosis_count
    FROM visits v
    JOIN diagnoses d ON v.visit_id = d.visit_id
    GROUP BY v.visit_id
)
SELECT p.patient_id, p.first_name, p.last_name, v.visit_date, v.reason_for_visit,
    td.diagnosis_count, 
    CASE 
        WHEN td.diagnosis_count > 3 THEN 'Complex Case'
        ELSE 'Simple Case'
    END AS case_complexity
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN total_diagnoses td ON v.visit_id = td.visit_id
JOIN vitals vt ON v.visit_id = vt.visit_id
JOIN (
    SELECT DISTINCT test_name FROM labs WHERE result_flag = 'High'
) high_labs ON vt.visit_id = v.visit_id
LEFT JOIN (
    SELECT DISTINCT imaging_id, visit_id FROM imaging
) img ON v.visit_id = img.visit_id
WHERE vt.blood_pressure_systolic > 140 
  AND EXISTS (SELECT 1 FROM medications m WHERE m.visit_id = v.visit_id AND m.medication_name = 'Aspirin');

-- Query 4
WITH risk_assessment AS (
    SELECT rs.patient_id, AVG(rs.score_value) AS avg_risk_score
    FROM risk_scores rs
    WHERE rs.calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY rs.patient_id
)
SELECT p.patient_id, p.first_name, et.encounter_type_name, pr.specialty,
    ra.avg_risk_score, 
    SUM(clm.claim_amount) AS total_claim_amount,
    PERCENT_RANK() OVER (ORDER BY ra.avg_risk_score DESC) AS risk_rank
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN providers pr ON v.provider_id = pr.provider_id
JOIN encounter_types et ON v.encounter_type_id = et.encounter_type_id
JOIN claim clm ON v.visit_id = clm.visit_id
JOIN risk_assessment ra ON p.patient_id = ra.patient_id
LEFT JOIN (
    SELECT DISTINCT a.patient_id FROM allergies a WHERE a.severity = 'Severe'
) severe_allergy ON p.patient_id = severe_allergy.patient_id
GROUP BY p.patient_id, p.first_name, et.encounter_type_name, pr.specialty, ra.avg_risk_score
HAVING SUM(clm.claim_amount) > 10000;

-- Query 5
WITH provider_performance AS (
    SELECT pr.provider_id, COUNT(DISTINCT v.visit_id) AS visit_count,
        MAX(clm.claim_amount) AS max_claim,
        MIN(clm.claim_amount) AS min_claim
    FROM providers pr
    JOIN visits v ON pr.provider_id = v.provider_id
    JOIN claims clm ON v.visit_id = clm.visit_id
    GROUP BY pr.provider_id
)
SELECT p.first_name, p.last_name, pr.provider_id, pr.specialty, prov_perf.visit_count,
    pr.npi_number, 
    CASE 
        WHEN prov_perf.max_claim > 5000 THEN 'High Biller'
        ELSE 'Regular Biller'
    END AS billing_level
FROM providers pr
JOIN provider_performance prov_perf ON pr.provider_id = prov_perf.provider_id
LEFT JOIN visits v ON pr.provider_id = v.provider_id
LEFT JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN procedures proc ON v.visit_id = proc.visit_id
JOIN (
    SELECT provider_id FROM clinical_notes WHERE LENGTH(note_text) > 500
) noted_providers ON pr.provider_id = noted_providers.provider_id
WHERE pr.specialty IN ('Cardiology', 'Orthopedics');

-- Query 6
WITH social_factors AS (
    SELECT se.patient_id, COUNT(*) AS sdoh_count
    FROM sdoh_entries se
    GROUP BY se.patient_id
),
income_data AS (
    SELECT i.patient_id, RANK() OVER (ORDER BY i.income_level DESC) AS income_rank
    FROM income_brackets i
)
SELECT p.patient_id, p.first_name, p.last_name, sf.sdoh_count, id.income_rank,
    AVG(pmt.amount) AS avg_payment_amount,
    SUM(b.amount) AS total_billed
FROM patients p
JOIN social_factors sf ON p.patient_id = sf.patient_id
JOIN income_data id ON p.patient_id = id.patient_id
LEFT JOIN claims c ON p.patient_id = c.patient_id
LEFT JOIN payments pmt ON c.claim_id = pmt.claim_id
LEFT JOIN billing b ON c.claim_id = b.claim_id
JOIN (
    SELECT DISTINCT condition_name FROM conditions WHERE condition_status = 'Active'
) active_conditions ON p.patient_id = active_conditions.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, sf.sdoh_count, id.income_rank
HAVING SUM(b.amount) > 2000;

-- Query 7
WITH emergency_visits AS (
    SELECT v.visit_id, v.patient_id, COUNT(*) AS emergency_count
    FROM visits v
    WHERE v.was_emergency
    GROUP BY v.visit_id, v.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, v.visit_date, ev.emergency_count,
    CASE 
        WHEN ev.emergency_count > 1 THEN 'Frequent Emergency Visitor'
        ELSE 'Occasional Emergency Visitor'
    END AS visitor_level,
    AVG(vt.blood_pressure_systolic) OVER (PARTITION BY p.patient_id) AS avg_systolic_bp
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN emergency_visits ev ON v.visit_id = ev.visit_id
JOIN vitals vt ON v.visit_id = vt.visit_id
JOIN (
    SELECT visit_id, COUNT(*) AS procedure_count FROM procedures GROUP BY visit_id
) proc_counts ON v.visit_id = proc_counts.visit_id
LEFT JOIN (
    SELECT DISTINCT visit_id FROM imaging WHERE imaging_type = 'X-ray'
) xrays ON v.visit_id = xrays.visit_id
WHERE p.language_id IN (SELECT language_id FROM languages WHERE language_name = 'English');

-- Query 8
WITH chronic_conditions AS (
    SELECT cond.patient_id, LISTAGG(cond.condition_name, ', ') AS conditions_list
    FROM conditions cond
    WHERE condition_status = 'Chronic'
    GROUP BY cond.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, cc.conditions_list,
    COUNT(DISTINCT m.medication_id) AS medication_count,
    CASE 
        WHEN COUNT(DISTINCT m.medication_id) > 3 THEN 'Polypharmacy'
        ELSE 'Regular'
    END AS medication_status
FROM patients p
JOIN chronic_conditions cc ON p.patient_id = cc.patient_id
LEFT JOIN medications m ON p.patient_id = m.patient_id
LEFT JOIN visits v ON m.visit_id = v.visit_id
JOIN (
    SELECT patient_id, MAX(score_value) AS max_risk FROM risk_scores GROUP BY patient_id
) risk_max ON p.patient_id = risk_max.patient_id
JOIN (
    SELECT DISTINCT screening_type FROM screenings WHERE result = 'Positive'
) positive_screenings ON p.patient_id IN (SELECT patient_id FROM screenings WHERE result = positive_screenings.screening_type)
GROUP BY p.patient_id, p.first_name, p.last_name, cc.conditions_list
HAVING SUM(m.medication_count) < 5;

-- Query 9
WITH avg_weight AS (
    SELECT v.patient_id, AVG(vt.weight_kg) AS avg_weight
    FROM visits v
    JOIN vitals vt ON v.visit_id = vt.visit_id
    GROUP BY v.patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, aw.avg_weight, ad.city,
    CASE 
        WHEN aw.avg_weight > 80 THEN 'Overweight'
        ELSE 'Normal Weight'
    END AS weight_category,
    SUM(vt.bmi) AS total_bmi,
    ROW_NUMBER() OVER (ORDER BY aw.avg_weight DESC) AS weight_rank
FROM patients p
JOIN avg_weight aw ON p.patient_id = aw.patient_id
LEFT JOIN addresses ad ON p.address_id = ad.address_id
LEFT JOIN vitals vt ON p.patient_id = vt.patient_id
JOIN (
    SELECT DISTINCT ls.lab_result_id FROM labs ls WHERE ls.result_flag = 'Normal'
) normal_labs ON vt.visit_id = normal_labs.lab_result_id
LEFT JOIN (
    SELECT DISTINCT note_id FROM clinical_notes WHERE note_type = 'Follow-up'
) follow_ups ON vt.visit_id = follow_ups.note_id
GROUP BY p.patient_id, p.first_name, p.last_name, aw.avg_weight, ad.city
HAVING total_bmi > 25;

-- Query 10
WITH lab_results AS (
    SELECT lr.visit_id, COUNT(*) AS lab_count, 
        AVG(lr.result_value) AS avg_result
    FROM labs lr
    WHERE lr.reported_date BETWEEN CURRENT_DATE - INTERVAL '6 months' AND CURRENT_DATE
    GROUP BY lr.visit_id
)
SELECT p.patient_id, p.first_name, p.last_name, lr.avg_result, pr.specialty,
    COUNT(DISTINCT v.visit_date) AS visit_count,
    AVG(cl.billed_amount) AS avg_billed_amount,
    CASE 
        WHEN lr.avg_result > 5 THEN 'High Avg Lab Value'
        ELSE 'Normal Avg Lab Value'
    END AS lab_value_status
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN lab_results lr ON v.visit_id = lr.visit_id
JOIN providers pr ON v.provider_id = pr.provider_id
JOIN claims cl ON v.visit_id = cl.visit_id
LEFT JOIN (
    SELECT visit_id FROM procedures WHERE procedure_code LIKE 'MR%'
) mri_procedures ON v.visit_id = mri_procedures.visit_id
JOIN (
    SELECT patient_id, COUNT(survey_id) AS survey_count FROM surveys GROUP BY patient_id
) survey_counts ON p.patient_id = survey_counts.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, lr.avg_result, pr.specialty
HAVING visit_count > 2;