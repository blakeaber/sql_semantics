-- Query 1
WITH RecentVisits AS (
    SELECT
        v.visit_id,
        v.patient_id,
        MAX(v.visit_date) AS last_visit_date
    FROM
        visits v
    GROUP BY
        v.visit_id, v.patient_id
)
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS full_name,
    rt.race_ethnicity_name,
    lang.language_name,
    AVG(COALESCE(cl.paid_amount, 0)) OVER (PARTITION BY p.language_id) AS avg_payment_by_language
FROM
    patients p
JOIN
    RecentVisits rv ON p.patient_id = rv.patient_id
JOIN
    languages lang ON p.language_id = lang.language_id
JOIN
    race_ethnicity rt ON p.race_ethnicity_id = rt.race_ethnicity_id
LEFT JOIN
    claims cl ON cl.patient_id = p.patient_id
WHERE
    rv.last_visit_date >= '2023-01-01';

-- Query 2
WITH ConditionCounts AS (
    SELECT
        c.patient_id,
        COUNT(*) as condition_count
    FROM
        conditions c
    WHERE
        c.condition_status = 'Active'
    GROUP BY
        c.patient_id
)
SELECT
    p.patient_id,
    CASE WHEN cc.condition_count > 5 THEN 'Complex'
         ELSE 'Simple' END AS condition_complexity,
    COALESCE(SUM(vs.billed_amount), 0) AS total_billed_amount
FROM
    patients p
JOIN
    ConditionCounts cc ON p.patient_id = cc.patient_id
LEFT JOIN
    claims vs ON vs.patient_id = p.patient_id
GROUP BY
    p.patient_id, cc.condition_count
HAVING
    total_billed_amount > 1000;

-- Query 3
WITH VisitCounts AS (
    SELECT
        v.patient_id,
        COUNT(*) AS visit_count
    FROM
        visits v
    WHERE
        v.was_emergency = TRUE
    GROUP BY
        v.patient_id
)
SELECT
    p.patient_id,
    pr.specialty AS provider_specialty,
    VisitCounts.visit_count,
    MAX(vs.claim_amount) AS max_claim_amount
FROM
    patients p
JOIN
    visits v ON v.patient_id = p.patient_id
JOIN
    providers pr ON v.provider_id = pr.provider_id
LEFT JOIN
    VisitCounts ON VisitCounts.patient_id = p.patient_id
LEFT JOIN
    claims vs ON vs.visit_id = v.visit_id
GROUP BY
    p.patient_id, pr.specialty, VisitCounts.visit_count;

-- Query 4
SELECT
    v.visit_id,
    e.encounter_type_name,
    di.diagnosis_code,
    COUNT(DISTINCT pr.procedure_code) AS unique_procedures,
    AVG(lab.result_value) AS avg_lab_result
FROM
    visits v
JOIN
    encounter_types e ON v.encounter_type_id = e.encounter_type_id
JOIN
    diagnoses di ON v.visit_id = di.visit_id
JOIN
    procedures pr ON v.visit_id = pr.visit_id
LEFT JOIN
    labs lab ON v.visit_id = lab.visit_id
GROUP BY
    v.visit_id, e.encounter_type_name, di.diagnosis_code
HAVING
    COUNT(DISTINCT pr.procedure_code) > 3;

-- Query 5
WITH LabResults AS (
    SELECT
        l.visit_id,
        AVG(l.result_value) AS avg_result_value
    FROM
        labs l
    GROUP BY
        l.visit_id
)
SELECT
    p.patient_id,
    CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
    SUM(m.medication_code) OVER (PARTITION BY p.patient_id) AS total_medication_code
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
JOIN
    providers pr ON v.provider_id = pr.provider_id
JOIN
    medications m ON v.visit_id = m.visit_id
JOIN
    LabResults lr ON v.visit_id = lr.visit_id
WHERE
    lr.avg_result_value > 5;

-- Query 6
SELECT
    s.survey_id,
    s.survey_type,
    SUM(CASE WHEN s.survey_score >= 80 THEN 1 ELSE 0 END) AS high_score_count,
    ROW_NUMBER() OVER (PARTITION BY s.survey_type ORDER BY s.survey_date DESC) AS survey_rank
FROM
    surveys s
JOIN
    patients p ON s.patient_id = p.patient_id
LEFT JOIN
    claims cl ON s.patient_id = cl.patient_id
WHERE
    cl.claim_status IN ('Paid', 'Processed')
GROUP BY
    s.survey_id, s.survey_type;

-- Query 7
WITH AvgIncome AS (
    SELECT
        i.patient_id,
        AVG(i.amount) AS avg_income
    FROM
        income_brackets i
    GROUP BY
        i.patient_id
)
SELECT
    p.patient_id,
    CASE WHEN ic.avg_income > 50000 THEN 'High' ELSE 'Low' END AS income_level_category,
    COUNT(distinct cl.claim_id) AS claim_count
FROM
    patients p
JOIN
    AvgIncome ic ON p.patient_id = ic.patient_id
LEFT JOIN
    claims cl ON p.patient_id = cl.patient_id
GROUP BY
    p.patient_id, ic.avg_income;

-- Query 8
WITH MedicationUsage AS (
    SELECT
        m.medication_name,
        COUNT(m.medication_id) AS usage_count
    FROM
        medications m
    GROUP BY
        m.medication_name
)
SELECT
    p.patient_id,
    a.allergen,
    m.usage_count,
    MAX(vs.billed_amount) AS max_billed
FROM
    patients p
LEFT JOIN
    allergies a ON p.patient_id = a.patient_id
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    MedicationUsage m ON v.visit_id = m.medication_name
LEFT JOIN
    claims vs ON vs.visit_id = v.visit_id
GROUP BY
    p.patient_id, a.allergen, m.usage_count;

-- Query 9
WITH RiskScores AS (
    SELECT
        r.patient_id,
        AVG(r.score_value) AS avg_score
    FROM
        risk_scores r
    GROUP BY
        r.patient_id
)
SELECT
    p.patient_id,
    rs.avg_score,
    CASE WHEN rs.avg_score > 70 THEN 'High Risk' ELSE 'Low Risk' END AS risk_category,
    COUNT(distinct o.order_id) AS order_count
FROM
    patients p
JOIN
    RiskScores rs ON p.patient_id = rs.patient_id
LEFT JOIN
    orders o ON p.patient_id = o.patient_id
GROUP BY
    p.patient_id, rs.avg_score;

-- Query 10
SELECT
    e.employment_id,
    e.employer_name,
    COUNT(DISTINCT h.housing_id) AS housing_count,
    SUM(CASE WHEN ins.plan_type = 'Premium' THEN 1 ELSE 0 END) AS premium_plan
FROM
    employment_status e
JOIN
    patients p ON e.patient_id = p.patient_id
LEFT JOIN
    housing_status h ON p.patient_id = h.patient_id
LEFT JOIN
    insurance ins ON p.insurance_id = ins.insurance_id
GROUP BY
    e.employment_id, e.employer_name;