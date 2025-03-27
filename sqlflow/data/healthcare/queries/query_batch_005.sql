WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)

SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name AS full_name,
    r.race_ethnicity_name,
    l.language_name,
    CASE 
        WHEN c.sum_billed > 5000 THEN 'High Spending'
        ELSE 'Normal Spending'
    END AS spending_category,
    COUNT(DISTINCT v.visit_id) OVER (PARTITION BY p.patient_id) AS total_visits
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    (SELECT visit_id, SUM(billed_amount) AS sum_billed FROM claims GROUP BY visit_id) c ON v.visit_id = c.visit_id
JOIN 
    address a ON p.address_id = a.address_id
JOIN 
    RecentVisits rv ON p.patient_id = rv.patient_id
JOIN 
    race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
JOIN 
    languages l ON p.language_id = l.language_id
WHERE 
    v.visit_date = rv.last_visit_date
HAVING 
    COUNT(DISTINCT r.race_ethnicity_id) > 1;

WITH TopConditions AS (
    SELECT patient_id, condition_name,
           DENSE_RANK() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) AS rank
    FROM conditions
)

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    sd.sdoh_type,
    ctn.condition_name,
    COUNT(m.medication_id) FILTER (WHERE m.start_date > '2023-01-01') AS recent_medications
FROM 
    patients p
JOIN 
    sdoh_entries sd ON p.patient_id = sd.patient_id
JOIN 
    TopConditions ctn ON p.patient_id = ctn.patient_id AND ctn.rank = 1
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    medications m ON v.visit_id = m.visit_id
JOIN 
    providers pr ON v.provider_id = pr.provider_id
WHERE 
    pr.specialty IN (
        SELECT specialty
        FROM providers
        WHERE location = 'New York'
    );

WITH EmergencyVisits AS (
    SELECT patient_id, COUNT(*) AS emergency_count
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    v.location AS last_visit_location,
    e.emergency_count,
    MAX(le.result_value) FILTER (WHERE le.test_name = 'Hemoglobin') AS max_hemoglobin
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    (SELECT visit_id, MAX(reported_date) AS max_reported_date FROM labs GROUP BY visit_id) lr ON v.visit_id = lr.visit_id
JOIN 
    labs le ON lr.visit_id = le.visit_id AND lr.max_reported_date = le.reported_date
LEFT JOIN 
    EmergencyVisits e ON p.patient_id = e.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, v.location, e.emergency_count;

WITH LastScreenings AS (
    SELECT patient_id, MAX(screening_date) AS last_screening_date
    FROM screenings
    GROUP BY patient_id
)

SELECT 
    pa.patient_id,
    pa.first_name AS patient_name,
    i.imaging_type,
    i.body_part,
    bc.billed_count,
    py.payment_total
FROM 
    patients pa
JOIN 
    imaging i ON i.visit_id = (
        SELECT visit_id
        FROM visits
        WHERE patient_id = pa.patient_id
        ORDER BY visit_date DESC
        LIMIT 1
    )
JOIN 
    (SELECT visit_id, COUNT(*) AS billed_count FROM billing GROUP BY visit_id) bc ON i.visit_id = bc.visit_id
LEFT JOIN 
    (SELECT claim_id, SUM(amount) AS payment_total FROM payments GROUP BY claim_id) py ON pa.insurance_id = py.claim_id
JOIN 
    LastScreenings ls ON pa.patient_id = ls.patient_id
WHERE 
    ls.last_screening_date IS NOT NULL;

WITH ActiveConditions AS (
    SELECT patient_id, condition_name
    FROM conditions
    WHERE condition_status = 'Active'
)

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    ind.income_level,
    emp.employment_type,
    ac.condition_name,
    AVG(vv.bmi) OVER (PARTITION BY p.patient_id) AS avg_bmi
FROM 
    patients p
JOIN 
    income_brackets ind ON p.patient_id = ind.patient_id
JOIN 
    employment_status emp ON p.patient_id = emp.patient_id
JOIN 
    ActiveConditions ac ON p.patient_id = ac.patient_id
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    vitals vv ON v.visit_id = vv.visit_id
WHERE 
    EXISTS (
        SELECT 1
        FROM sdoh_entries sd
        WHERE sd.patient_id = p.patient_id AND sd.sdoh_type = 'Food Insecurity'
    );

WITH ChronicPatients AS (
    SELECT patient_id, COUNT(*) AS chronic_condition_count
    FROM conditions
    WHERE condition_status = 'Chronic'
    GROUP BY patient_id
)

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    co.chronic_condition_count,
    ROUND(AVG(pb.amount), 2) AS average_billing_amount,
    COUNT(sv.survey_id) FILTER (WHERE sv.survey_score > 8) AS high_score_surveys
FROM 
    patients p
JOIN 
    ChronicPatients co ON p.patient_id = co.patient_id
LEFT JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    (SELECT billing_id, amount FROM billing) pb ON v.visit_id = pb.billing_id
LEFT JOIN 
    surveys sv ON p.patient_id = sv.patient_id
WHERE 
    co.chronic_condition_count > 2
GROUP BY 
    p.patient_id, p.first_name, p.last_name, co.chronic_condition_count;

SELECT 
    pa.patient_id,
    pa.first_name || ' ' || pa.last_name AS full_name,
    MIN(v.blood_pressure_systolic) AS min_bp_systolic,
    MAX(v.temperature_c) AS max_temperature,
    c.notes_summary,
    CASE
        WHEN eye.count > 0 THEN 'Eye Exam Needed'
        ELSE 'No Eye Exam Required'
    END AS eye_exam_status
FROM 
    patients pa
JOIN 
    visits vi ON pa.patient_id = vi.patient_id
JOIN 
    vitals v ON vi.visit_id = v.visit_id
LEFT JOIN 
    (SELECT patient_id, COUNT(*) AS count FROM screenings WHERE screening_type = 'Eye Exam' AND result = 'Unsatisfactory' GROUP BY patient_id) eye ON pa.patient_id = eye.patient_id
JOIN 
    (SELECT visit_id, provider_id, note_summary AS notes_summary FROM clinical_notes WHERE note_type = 'Discharge Summary') c ON vi.visit_id = c.visit_id
WHERE 
    vi.was_emergency = FALSE
GROUP BY 
    pa.patient_id, pa.full_name, c.notes_summary, eye.count;

WITH SpecialtyCare AS (
    SELECT provider_id, specialty
    FROM providers
    WHERE specialty IN ('Cardiology', 'Neurology')
)

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    pr.specialty,
    CASE
        WHEN COUNT(d.diagnosis_id) > 5 THEN 'Frequent Diagnoses'
        ELSE 'Regular Diagnoses'
    END AS diagnosis_frequency,
    SUM(cl.claim_amount) AS total_claims
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    SpecialtyCare pr ON v.provider_id = pr.provider_id
LEFT JOIN 
    diagnoses d ON v.visit_id = d.visit_id
LEFT JOIN 
    claims cl ON v.visit_id = cl.visit_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, pr.specialty
HAVING 
    COUNT(v.visit_id) > 2;

WITH RecentDiagnoses AS (
    SELECT visit_id, MAX(diagnosis_date) AS last_diagnosis_date
    FROM diagnoses
    GROUP BY visit_id
)

SELECT 
    pat.patient_id,
    pat.first_name,
    pat.last_name,
    ag.allergy_count,
    pr.procedure_code,
    co.condition_name,
    CASE
        WHEN pr.procedure_code IS NULL THEN 'No Procedure'
        ELSE pr.procedure_code
    END AS procedure_status
FROM 
    patients pat
LEFT JOIN 
    (SELECT patient_id, COUNT(*) AS allergy_count FROM allergies GROUP BY patient_id) ag ON pat.patient_id = ag.patient_id
LEFT JOIN 
    procedures pr ON pr.visit_id = (
        SELECT visit_id
        FROM visits
        WHERE patient_id = pat.patient_id
        AND visit_date = (SELECT MAX(visit_date) FROM visits WHERE patient_id = pat.patient_id)
    )
LEFT JOIN 
    conditions co ON pat.patient_id = co.patient_id
JOIN 
    RecentDiagnoses rd ON rd.visit_id = pr.visit_id
WHERE 
    co.condition_status = 'Active'
AND 
    rd.last_diagnosis_date IS NOT NULL;

WITH LastImaging AS (
    SELECT visit_id, MAX(performed_date) AS last_imaging_date
    FROM imaging
    GROUP BY visit_id
)

SELECT 
    pats.patient_id,
    pats.first_name || ' ' || pats.last_name AS full_name,
    COUNT(CASE WHEN im.body_part = 'Abdomen' THEN 1 END) AS abdomen_imagings,
    ANY_VALUE(String_agg(m.medication_name, ', ' ORDER BY m.start_date DESC)) AS recent_medications,
    AVG(lab.result_value) FILTER (WHERE lab.test_name = 'Cholesterol') AS avg_cholesterol
FROM 
    patients pats
JOIN 
    visits vis ON pats.patient_id = vis.patient_id
LEFT JOIN 
    imaging im ON vis.visit_id = im.visit_id
LEFT JOIN 
    medications m ON vis.visit_id = m.visit_id
JOIN 
    labs lab ON vis.visit_id = lab.visit_id
JOIN 
    LastImaging li ON li.visit_id = vis.visit_id AND li.last_imaging_date = im.performed_date
GROUP BY 
    pats.patient_id, pats.full_name;