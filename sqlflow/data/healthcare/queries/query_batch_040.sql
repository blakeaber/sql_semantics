SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    AVG(vv.bmi) AS avg_bmi,
    CASE WHEN COUNT(a.allergy_id) > 0 THEN 'Yes' ELSE 'No' END AS has_allergies
FROM 
    patients p
JOIN 
    (SELECT visit_id, patient_id, bmi FROM visits v JOIN vitals vi ON v.visit_id = vi.visit_id) vv ON p.patient_id = vv.patient_id
LEFT JOIN 
    allergies a ON p.patient_id = a.patient_id
LEFT JOIN 
    (SELECT * FROM screenings WHERE result = 'Positive') sc ON p.patient_id = sc.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name
HAVING 
    AVG(vv.bmi) > 25;

WITH recent_visits AS (
    SELECT 
        visit_id, 
        patient_id, 
        visit_date 
    FROM 
        visits 
    WHERE 
        visit_date > (SELECT CURRENT_DATE - INTERVAL '1 year')
)
SELECT 
    r.patient_id,
    COUNT(r.visit_id) AS visit_count,
    rs.race_ethnicity_name
FROM 
    recent_visits r
JOIN 
    patients p ON r.patient_id = p.patient_id
JOIN 
    race_ethnicity rs ON p.race_ethnicity_id = rs.race_ethnicity_id
GROUP BY 
    r.patient_id, rs.race_ethnicity_name
ORDER BY 
    visit_count DESC;

SELECT 
    pr.provider_id, 
    pr.specialty, 
    COUNT(DISTINCT vv.visit_id) AS num_visits,
    AVG(v.billed_amount) AS avg_billed
FROM 
    providers pr
JOIN 
    (SELECT visit_id, provider_id FROM visits) vv ON pr.provider_id = vv.provider_id
JOIN 
    (SELECT visit_id, billed_amount FROM claims WHERE claim_status = 'Paid') v ON vv.visit_id = v.visit_id
GROUP BY 
    pr.provider_id, pr.specialty
HAVING 
    COUNT(DISTINCT vv.visit_id) > 10;

WITH current_employment AS (
    SELECT 
        patient_id,
        employment_type
    FROM 
        employment_status WHERE status_date = (SELECT MAX(status_date) FROM employment_status)
),
recent_medications AS (
    SELECT 
        visit_id, 
        medication_name, 
        patient_id 
    FROM 
        medications 
    WHERE 
        start_date > (SELECT CURRENT_DATE - INTERVAL '6 months')
)
SELECT 
    e.patient_id, 
    e.employment_type, 
    COUNT(m.medication_name) AS medication_count
FROM 
    current_employment e
JOIN 
    recent_medications m ON e.patient_id = m.patient_id
GROUP BY 
    e.patient_id, e.employment_type
ORDER BY 
    medication_count DESC;

SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    SUM(c.claim_amount) AS total_claim_amount,
    COUNT(DISTINCT d.diagnosis_id) AS distinct_diagnoses,
    MAX(ds.diagnosis_date) AS last_diagnosis_date
FROM 
    patients p
JOIN 
    claims c ON p.patient_id = c.patient_id
JOIN 
    (SELECT visit_id, diagnosis_id, diagnosis_date FROM diagnoses) d ON c.visit_id = d.visit_id
LEFT JOIN 
    (SELECT * FROM diagnoses WHERE diagnosis_type = 'Chronic') ds ON d.diagnosis_id = ds.diagnosis_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name
HAVING 
    SUM(c.claim_amount) > 5000;

WITH total_payments AS (
    SELECT 
        claim_id, 
        SUM(amount) AS total_amount
    FROM 
        payments 
    GROUP BY 
        claim_id
),
claims_with_balance AS (
    SELECT 
        claim_id, 
        billed_amount - COALESCE(tp.total_amount, 0) AS balance
    FROM 
        claims c
    LEFT JOIN 
        total_payments tp ON c.claim_id = tp.claim_id
    HAVING 
        (billed_amount - COALESCE(tp.total_amount, 0)) > 0
)
SELECT 
    c.patient_id, 
    p.first_name, 
    p.last_name, 
    COUNT(cb.claim_id) AS unpaid_claim_count,
    SUM(cb.balance) AS total_unpaid_balance
FROM 
    claims_with_balance cb
JOIN 
    patients p ON cb.patient_id = p.patient_id
GROUP BY 
    c.patient_id, p.first_name, p.last_name;

SELECT 
    p.patient_id,
    AVG(lb.result_value) AS avg_hb,
    MAX(lb.reported_date) AS last_reported,
    COUNT(DISTINCT ic.imaging_id) AS imaging_tests
FROM 
    patients p
JOIN 
    (SELECT visit_id, patient_id FROM visits) v ON p.patient_id = v.patient_id
JOIN 
    labs lb ON v.visit_id = lb.visit_id AND lb.test_name = 'Hemoglobin'
LEFT JOIN 
    imaging ic ON v.visit_id = ic.visit_id
GROUP BY 
    p.patient_id
HAVING 
    AVG(lb.result_value) IS NOT NULL;

WITH high_risk_patients AS (
    SELECT 
        patient_id 
    FROM 
        risk_scores 
    WHERE 
        score_value > 80
),
joined_data AS (
    SELECT 
        hr.patient_id, 
        v.visit_id, 
        s.symptom
    FROM 
        high_risk_patients hr
    JOIN 
        visits v ON hr.patient_id = v.patient_id
    LEFT JOIN 
        symptoms s ON v.visit_id = s.visit_id
)
SELECT 
    jd.patient_id, 
    COUNT(DISTINCT jd.visit_id) AS num_visits,
    MAX(jd.visit_id) AS last_visit,
    COUNT(survey_id) AS surveys_taken
FROM 
    joined_data jd
LEFT JOIN 
    surveys su ON jd.patient_id = su.patient_id
GROUP BY 
    jd.patient_id
ORDER BY 
    num_visits DESC;

SELECT 
    p.patient_id, 
    p.first_name || ' ' || p.last_name AS full_name,
    it.imaging_type,
    MAX(i.performed_date) AS last_imaging_date
FROM 
    patients p
JOIN 
    (SELECT visit_id, imaging_type, performed_date FROM imaging) i ON p.patient_id = (SELECT patient_id FROM visits WHERE visit_id = i.visit_id)
LEFT JOIN 
    (SELECT imaging_type, COUNT(imaging_id) AS icount FROM imaging GROUP BY imaging_type) it ON i.imaging_type = it.imaging_type
GROUP BY 
    p.patient_id, p.first_name, p.last_name, it.imaging_type
HAVING 
    COUNT(i.imaging_id) > 1;

WITH patient_conditions AS (
    SELECT 
        patient_id,
        condition_name
    FROM 
        conditions 
    WHERE 
        condition_status = 'Active'
),
visit_metrics AS (
    SELECT 
        visit_id, 
        patient_id, 
        COUNT(symptom_id) AS symptom_count
    FROM 
        visits v
    LEFT JOIN 
        symptoms s ON v.visit_id = s.visit_id
    GROUP BY 
        visit_id, patient_id
)
SELECT 
    pc.patient_id, 
    pc.condition_name,
    AVG(vm.symptom_count) AS avg_symptoms_per_visit,
    CASE WHEN AVG(vm.symptom_count) > 5 THEN 'Frequent' ELSE 'Stable' END AS symptom_status
FROM 
    patient_conditions pc
JOIN 
    visit_metrics vm ON pc.patient_id = vm.patient_id
GROUP BY 
    pc.patient_id, pc.condition_name
HAVING 
    AVG(vm.symptom_count) IS NOT NULL;
