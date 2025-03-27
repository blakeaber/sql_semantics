WITH RecentVisits AS (
    SELECT
        v.patient_id,
        MAX(v.visit_date) AS last_visit
    FROM
        visits v
    JOIN
        diagnoses d ON v.visit_id = d.visit_id
    GROUP BY
        v.patient_id
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    eth.race_ethnicity_name,
    (
        SELECT AVG(l.result_value)
        FROM labs l
        WHERE l.visit_id IN (
            SELECT visit_id FROM visits WHERE patient_id = p.patient_id
        )
    ) AS avg_lab_value,
    CASE
        WHEN AVG(risk.score_value) > 5 THEN 'High Risk'
        ELSE 'Low Risk'
    END AS risk_level
FROM
    patients p
JOIN
    RecentVisits rv ON p.patient_id = rv.patient_id
JOIN
    race_ethnicity eth ON p.race_ethnicity_id = eth.race_ethnicity_id
LEFT JOIN
    risk_scores risk ON p.patient_id = risk.patient_id
WHERE
    risk.calculated_date = rv.last_visit
GROUP BY
    p.patient_id, p.first_name, p.last_name, eth.race_ethnicity_name
HAVING COUNT(DISTINCT risk.score_type) > 3
ORDER BY
    risk_level DESC;


WITH PatientDiagnosesCount AS (
    SELECT
        v.patient_id,
        COUNT(d.diagnosis_id) AS total_diagnoses
    FROM
        visits v
    INNER JOIN diagnoses d ON v.visit_id = d.visit_id
    GROUP BY v.patient_id
)

SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS full_name,
    i.payer_name AS insurance_provider,
    CASE
        WHEN TotalPatientCost() > 10000 THEN 'High Cost'
        ELSE 'Normal Cost'
    END AS cost_category
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    insurance i ON p.insurance_id = i.insurance_id
JOIN
    PatientDiagnosesCount dc ON p.patient_id = dc.patient_id
WHERE
    p.language_id IN (
        SELECT language_id
        FROM languages
        WHERE language_name = 'English'
    )
GROUP BY
    p.patient_id, p.first_name, p.last_name, i.payer_name
HAVING AVG(dc.total_diagnoses) > 5;


WITH AverageLabResults AS (
    SELECT
        v.visit_id,
        AVG(l.result_value) AS avg_result
    FROM
        visits v
    JOIN
        labs l ON v.visit_id = l.visit_id
    WHERE
        l.collected_date BETWEEN '2023-01-01' AND '2023-06-30'
    GROUP BY
        v.visit_id
)

SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    AVG(alr.avg_result) AS patient_avg_lab,
    SUM(pb.amount) AS total_billed
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    AverageLabResults alr ON v.visit_id = alr.visit_id
JOIN
    procedures pc ON v.visit_id = pc.visit_id
JOIN
    billing bl ON v.visit_id = bl.claim_id
JOIN
    payments pb ON bl.claim_id = pb.claim_id
WHERE
    v.was_emergency = TRUE
GROUP BY
    p.patient_id, p.first_name, p.last_name
ORDER BY
    patient_avg_lab DESC;


WITH EmergencyStatistics AS (
    SELECT
        v.patient_id,
        COUNT(DISTINCT v.visit_id) AS emergency_visits
    FROM
        visits v
    WHERE
        v.was_emergency = TRUE
    GROUP BY
        v.patient_id
)

SELECT
    p.patient_id,
    rs.score_value,
    COUNT(emg.emergency_visits) AS emergency_count,
    CASE
        WHEN rs.score_value > 7 THEN 'Critical'
        ELSE 'Stable'
    END AS patient_condition
FROM
    patients p
JOIN
    EmergencyStatistics emg ON p.patient_id = emg.patient_id
LEFT JOIN
    risk_scores rs ON p.patient_id = rs.patient_id
WHERE
    rs.calculated_date > NOW() - INTERVAL '1 year'
GROUP BY
    p.patient_id, rs.score_value
HAVING COUNT(emg.emergency_visits) > 1;


WITH ProviderSummary AS (
    SELECT
        pr.provider_id,
        COUNT(DISTINCT pc.procedure_id) AS procedure_count
    FROM
        providers pr
    JOIN
        visits v ON pr.provider_id = v.provider_id
    JOIN
        procedures pc ON v.visit_id = pc.visit_id
    GROUP BY
        pr.provider_id
)

SELECT
    pr.provider_id,
    CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
    ps.procedure_count,
    CASE
        WHEN CHAR_LENGTH(pr.specialty) > 15 THEN pr.specialty
        ELSE 'General'
    END AS specialty_category
FROM
    providers pr
LEFT JOIN
    ProviderSummary ps ON pr.provider_id = ps.provider_id
WHERE
    pr.provider_id IN (
        SELECT provider_id FROM visits WHERE visit_date > '2021-01-01'
    )
GROUP BY
    pr.provider_id, pr.first_name, pr.last_name, ps.procedure_count
ORDER BY
    ps.procedure_count DESC;


WITH PatientVitals AS (
    SELECT
        v.visit_id,
        AVG(vt.bmi) AS avg_bmi
    FROM
        visits v
    JOIN
        vitals vt ON v.visit_id = vt.visit_id
    GROUP BY
        v.visit_id
)

SELECT
    p.patient_id,
    pd.condition_name AS chronic_condition,
    AVG(vt.avg_bmi) OVER (PARTITION BY pd.condition_name) AS condition_avg_bmi,
    CASE
        WHEN AVG(vt.avg_bmi) > 25 THEN 'High BMI'
        ELSE 'Normal BMI'
    END AS bmi_status
FROM
    patients p
JOIN
    conditions pd ON p.patient_id = pd.patient_id
LEFT JOIN
    PatientVitals vt ON vt.visit_id = (
        SELECT visit_id FROM visits WHERE patient_id = p.patient_id ORDER BY visit_date DESC LIMIT 1
    )
WHERE
    pd.condition_status = 'active'
GROUP BY
    p.patient_id, pd.condition_name
HAVING bmi_status = 'High BMI';


WITH ActiveAllergies AS (
    SELECT
        patient_id,
        COUNT(allergy_id) AS allergy_count
    FROM
        allergies
    WHERE
        severity = 'high'
    GROUP BY
        patient_id
)

SELECT
    p.patient_id,
    a.allergy_count,
    eth.race_ethnicity_name,
    AVG(cl.claim_amount) AS avg_claims
FROM
    patients p
LEFT JOIN
    ActiveAllergies a ON p.patient_id = a.patient_id
LEFT JOIN
    race_ethnicity eth ON p.race_ethnicity_id = eth.race_ethnicity_id
LEFT JOIN
    claims cl ON p.patient_id = cl.patient_id
WHERE
    a.allergy_count IS NOT NULL
GROUP BY
    p.patient_id, a.allergy_count, eth.race_ethnicity_name
ORDER BY
    avg_claims DESC;


WITH IncomeDistribution AS (
    SELECT
        patient_id,
        COUNT(income_id) AS income_records
    FROM
        income_brackets
    WHERE
        source = 'employment'
    GROUP BY
        patient_id
)

SELECT
    p.patient_id,
    emp.employment_type,
    COUNT(DISTINCT s.survey_id) AS survey_count,
    CASE
        WHEN COUNT(DISTINCT s.survey_id) > 2 THEN 'Active'
        ELSE 'Inactive'
    END AS survey_participation
FROM
    patients p
JOIN
    employment_status emp ON p.patient_id = emp.patient_id
LEFT JOIN
    surveys s ON p.patient_id = s.patient_id
JOIN
    IncomeDistribution id ON p.patient_id = id.patient_id
GROUP BY
    p.patient_id, emp.employment_type
HAVING id.income_records > 1;


WITH LabAndBill AS (
    SELECT
        l.visit_id,
        SUM(bl.amount) AS billed_amount
    FROM
        labs l
    JOIN
        billing bl ON l.visit_id = bl.claim_id
    WHERE
        l.result_flag = 'abnormal'
    GROUP BY
        l.visit_id
)

SELECT
    p.patient_id,
    COUNT(lab.visit_id) AS abnormal_lab_counts,
    SUM(lb.billed_amount) AS total_billed
FROM
    patients p
LEFT JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    LabAndBill lb ON v.visit_id = lb.visit_id
WHERE
    p.patient_id IN (
        SELECT patient_id FROM conditions WHERE condition_status = 'chronic'
    )
GROUP BY
    p.patient_id
HAVING SUM(lb.billed_amount) > 500;


WITH AnnualVisitCount AS (
    SELECT
        patient_id,
        COUNT(visit_id) AS visit_count
    FROM
        visits
    WHERE
        visit_date BETWEEN '2022-01-01' AND '2022-12-31'
    GROUP BY
        patient_id
)

SELECT
    p.patient_id,
    hs.housing_type,
    AVG(sr.survey_score) AS avg_survey_score,
    CASE
        WHEN AVG(sr.survey_score) > 75 THEN 'High Satisfaction'
        ELSE 'Moderate Satisfaction'
    END AS satisfaction_level
FROM
    patients p
JOIN
    housing_status hs ON p.patient_id = hs.patient_id
LEFT JOIN
    surveys sr ON p.patient_id = sr.patient_id
JOIN
    AnnualVisitCount avc ON p.patient_id = avc.patient_id
GROUP BY
    p.patient_id, hs.housing_type
HAVING avc.visit_count > 2;