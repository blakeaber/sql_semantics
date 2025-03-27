WITH RecentDiagnosis AS (
    SELECT 
        patient_id,
        MAX(diagnosis_date) AS last_diagnosis_date
    FROM 
        diagnoses
    GROUP BY 
        patient_id
),
ProviderInfo AS (
    SELECT 
        p.provider_id, 
        CONCAT(p.first_name, ' ', p.last_name) AS provider_full_name,
        p.specialty
    FROM 
        providers p
)
SELECT 
    pd.patient_id,
    pd.first_name,
    pd.last_name,
    rd.last_diagnosis_date,
    COUNT(v.visit_id) AS total_visits,
    MAX(v.visit_date) AS latest_visit_date,
    pi.provider_full_name,
    pi.specialty,
    CASE 
        WHEN COUNT(v.visit_id) > 5 THEN 'Frequent'
        ELSE 'Infrequent'
    END AS visit_frequency
FROM 
    patients pd
JOIN 
    visits v ON pd.patient_id = v.patient_id
JOIN 
    RecentDiagnosis rd ON pd.patient_id = rd.patient_id
JOIN 
    (SELECT visit_id, provider_id FROM visits) v2 
    ON v.visit_id = v2.visit_id
JOIN 
    ProviderInfo pi 
    ON v2.provider_id = pi.provider_id
GROUP BY 
    pd.patient_id, pd.first_name, pd.last_name, rd.last_diagnosis_date, pi.provider_full_name, pi.specialty
HAVING 
    COUNT(v.visit_id) > 2;


WITH PatientMedications AS (
    SELECT 
        patient_id,
        medication_name,
        COUNT(*) AS medication_count
    FROM 
        medications m
    JOIN 
        visits v ON m.visit_id = v.visit_id
    GROUP BY 
        patient_id, medication_name
),
Top3Medications AS (
    SELECT 
        patient_id,
        medication_name,
        RANK() OVER (PARTITION BY patient_id ORDER BY medication_count DESC) AS medication_rank
    FROM 
        PatientMedications
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    tm.medication_name,
    COUNT(d.diagnosis_id) AS total_diagnoses,
    MAX(d.diagnosis_date) AS recent_diagnosis,
    COALESCE(i.income_level, 'Unknown') AS income_bracket
FROM 
    patients p
JOIN 
    Top3Medications tm ON p.patient_id = tm.patient_id AND tm.medication_rank <= 3
JOIN 
    diagnoses d ON p.patient_id = (SELECT v.patient_id FROM visits v WHERE v.visit_id = d.visit_id)
LEFT JOIN 
    income_brackets i ON p.patient_id = i.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, tm.medication_name, i.income_level;


WITH VisitCounts AS (
    SELECT 
        v.patient_id,
        COUNT(*) AS visit_count
    FROM 
        visits v
    GROUP BY 
        v.patient_id
),
ConditionStatusCount AS (
    SELECT 
        c.patient_id,
        c.condition_status,
        COUNT(*) AS status_count
    FROM 
        conditions c
    GROUP BY 
        c.patient_id, c.condition_status
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    CASE 
        WHEN vc.visit_count > 10 THEN 'High'
        WHEN vc.visit_count BETWEEN 5 AND 10 THEN 'Moderate'
        ELSE 'Low'
    END AS visit_activity,
    cs.condition_status,
    cs.status_count
FROM 
    patients p
JOIN 
    VisitCounts vc ON p.patient_id = vc.patient_id
JOIN 
    ConditionStatusCount cs ON p.patient_id = cs.patient_id
WHERE 
    cs.status_count > 3;


WITH FrequentSymptoms AS (
    SELECT 
        visit_id,
        symptom,
        COUNT(*) AS symptom_occurrences
    FROM 
        symptoms
    GROUP BY 
        visit_id, symptom
),
PatientDemographics AS (
    SELECT 
        p.patient_id,
        r.race_ethnicity_name,
        l.language_name,
        p.gender
    FROM 
        patients p
    LEFT JOIN 
        race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
    LEFT JOIN 
        languages l ON p.language_id = l.language_id
)
SELECT 
    pd.patient_id,
    pd.race_ethnicity_name,
    pd.language_name,
    pd.gender,
    fs.symptom,
    fs.symptom_occurrences,
    AVG(lb.result_value) AS average_lab_result
FROM 
    visits v
JOIN 
    FrequentSymptoms fs ON v.visit_id = fs.visit_id
JOIN 
    labs lb ON v.visit_id = lb.visit_id
JOIN 
    PatientDemographics pd ON v.patient_id = pd.patient_id
GROUP BY 
    pd.patient_id, pd.race_ethnicity_name, pd.language_name, pd.gender, fs.symptom, fs.symptom_occurrences;


WITH ProviderSpecialty AS (
    SELECT 
        v.visit_id,
        pr.specialty
    FROM 
        visits v
    JOIN 
        providers pr ON v.provider_id = pr.provider_id
),
EmergencyVisitCount AS (
    SELECT 
        patient_id,
        COUNT(*) AS emergency_visits
    FROM 
        visits
    WHERE 
        was_emergency = TRUE
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    ps.specialty,
    COUNT(d.diagnosis_id) AS diagnosis_count,
    MAX(d.diagnosis_date) AS latest_diagnosis,
    evc.emergency_visits,
    CASE 
        WHEN evc.emergency_visits > 3 THEN 'High Emergency User'
        ELSE 'Low Emergency User'
    END AS emergency_category
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    diagnoses d ON v.visit_id = d.visit_id
JOIN 
    ProviderSpecialty ps ON v.visit_id = ps.visit_id
LEFT JOIN 
    EmergencyVisitCount evc ON p.patient_id = evc.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, ps.specialty, evc.emergency_visits;


WITH RecentLabResults AS (
    SELECT 
        visit_id,
        MAX(reported_date) AS most_recent_lab_date
    FROM 
        labs
    GROUP BY 
        visit_id
),
MedicationsPerVisit AS (
    SELECT 
        visit_id,
        COUNT(*) AS medication_count
    FROM 
        medications
    GROUP BY 
        visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    pi.payer_name,
    COUNT(b.billing_id) AS total_billed_services,
    SUM(b.amount) AS total_billed_amount,
    AVG(lr.result_value) AS average_recent_lab_value,
    mv.medication_count
FROM 
    patients p
LEFT JOIN 
    insurance i ON p.insurance_id = i.insurance_id
LEFT JOIN 
    billing b ON (SELECT c.claim_id FROM claims c WHERE c.patient_id = p.patient_id) = b.claim_id
LEFT JOIN 
    RecentLabResults lr ON (SELECT v.visit_id FROM visits v WHERE v.patient_id = p.patient_id) = lr.visit_id
LEFT JOIN 
    MedicationsPerVisit mv ON lr.visit_id = mv.visit_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, pi.payer_name, mv.medication_count;


WITH BMIRecords AS (
    SELECT 
        visit_id,
        bmi
    FROM 
        vitals
    WHERE 
        bmi IS NOT NULL
),
MatchingConditions AS (
    SELECT 
        patient_id,
        COUNT(*) AS chronic_conditions
    FROM 
        conditions
    WHERE 
        condition_status = 'Chronic'
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    COUNT(pr.procedure_id) AS procedures_count,
    MAX(pr.procedure_date) AS last_procedure_date,
    AVG(bmi.bmi) AS average_bmi,
    mc.chronic_conditions
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    procedures pr ON v.visit_id = pr.visit_id
LEFT JOIN 
    BMIRecords bmi ON v.visit_id = bmi.visit_id
LEFT JOIN 
    MatchingConditions mc ON p.patient_id = mc.patient_id
GROUP BY 
    p.patient_id, mc.chronic_conditions;


WITH MainAddress AS (
    SELECT 
        a.patient_id,
        adr.city,
        adr.state
    FROM 
        addresses adr
    JOIN 
        patients a ON adr.address_id = a.address_id
),
SurveyParticipation AS (
    SELECT 
        patient_id,
        COUNT(*) AS surveys_count,
        AVG(survey_score) AS avg_survey_score
    FROM 
        surveys
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    ma.city,
    ma.state,
    sp.surveys_count,
    sp.avg_survey_score,
    TOTAL(v.blood_pressure_systolic + v.blood_pressure_diastolic) as total_blood_pressure
FROM 
    patients p
LEFT JOIN 
    MainAddress ma ON p.patient_id = ma.patient_id
LEFT JOIN 
    SurveyParticipation sp ON p.patient_id = sp.patient_id
JOIN 
    visits v ON p.patient_id = v.patient_id
WHERE 
    sp.surveys_count > 2
GROUP BY 
    p.patient_id, ma.city, ma.state, sp.surveys_count, sp.avg_survey_score;


WITH ConditionDetails AS (
    SELECT 
        patient_id,
        condition_name,
        RANK() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) AS rank
    FROM 
        conditions
),
ActiveCareTeams AS (
    SELECT 
        patient_id,
        team_name
    FROM 
        patient_care_team pct
    JOIN 
        care_teams ct ON pct.care_team_id = ct.care_team_id
)
SELECT 
    p.patient_id,
    CASE 
        WHEN m.gender = 'Male' THEN m.diagnosis_code
        ELSE NULL
    END AS male_specific_diagnosis,
    NULLIF(m.procedure_description, '') AS non_empty_procedure,
    DISTINCTCM(active_team.team_name) AS unique_team_names
FROM 
    patients p
JOIN 
    (SELECT visit_id, gender FROM visits v JOIN patients p ON v.patient_id = p.patient_id) m 
    ON p.patient_id = m.patient_id
JOIN 
    diagnoses d ON m.visit_id = d.visit_id
JOIN 
    procedures pr ON m.visit_id = pr.visit_id
JOIN 
    ConditionDetails cd ON p.patient_id = cd.patient_id AND cd.rank = 1
JOIN 
    ActiveCareTeams active_team ON p.patient_id = active_team.patient_id
WHERE 
    pr.procedure_date > (SELECT MAX(condition.resolved_date) FROM conditions condition WHERE condition.patient_id = p.patient_id)
GROUP BY 
    p.patient_id, m.diagnosis_code, m.procedure_description;


WITH ScreeningResults AS (
    SELECT 
        patient_id,
        screening_type,
        result,
        screening_date,
        RANK() OVER (PARTITION BY patient_id ORDER BY screening_date DESC) AS rank
    FROM 
        screenings
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    sr.screening_type,
    sr.result,
    CASE
        WHEN MONTH(p.date_of_birth) BETWEEN 1 AND 3 THEN 'Q1'
        WHEN MONTH(p.date_of_birth) BETWEEN 4 AND 6 THEN 'Q2'
        ELSE 'Later'
    END AS birth_quarter
FROM 
    patients p
JOIN 
    ScreeningResults sr ON p.patient_id = sr.patient_id AND sr.rank = 1
JOIN 
    insurance i ON p.insurance_id = i.insurance_id
JOIN 
    languages lang ON p.language_id = lang.language_id
WHERE 
    i.payer_name = 'Medicare'
GROUP BY 
    p.patient_id, p.first_name, p.last_name, sr.screening_type, sr.result;