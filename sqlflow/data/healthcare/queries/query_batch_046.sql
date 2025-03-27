-- Query 1: Calculate average BMI by age group and gender across all visits
WITH AgeGroups AS (
    SELECT 
        patient_id,
        CASE 
            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) <= 18 THEN '0-18'
            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) <= 35 THEN '19-35'
            ELSE '36+' 
        END AS age_group
    FROM 
        patients
),
PatientVitals AS (
    SELECT 
        v.visit_id,
        p.patient_id,
        v.bmi,
        EXTRACT(YEAR FROM v.recorded_at) AS visit_year
    FROM 
        vitals v
    JOIN 
        visits vs ON vs.visit_id = v.visit_id
    JOIN 
        patients p ON p.patient_id = vs.patient_id
    WHERE 
        v.bmi IS NOT NULL
)
SELECT 
    ag.age_group,
    p.gender,
    pv.visit_year,
    AVG(pv.bmi) AS avg_bmi
FROM 
    PatientVitals pv
JOIN 
    AgeGroups ag ON ag.patient_id = pv.patient_id
JOIN 
    patients p ON p.patient_id = pv.patient_id
GROUP BY 
    ag.age_group, p.gender, pv.visit_year
HAVING 
    COUNT(pv.bmi) > 1;

-- Query 2: Summarize allergies and conditions, segmented by race and gender
WITH PatientAllergies AS (
    SELECT 
        p.patient_id,
        p.gender,
        re.race_ethnicity_name,
        al.allergen,
        COUNT(al.allergy_id) AS allergy_count
    FROM 
        patients p
    JOIN 
        allergies al ON al.patient_id = p.patient_id
    JOIN 
        race_ethnicity re ON re.race_ethnicity_id = p.race_ethnicity_id
    GROUP BY 
        p.patient_id, p.gender, re.race_ethnicity_name, al.allergen
)
SELECT 
    pa.race_ethnicity_name,
    pa.gender,
    pa.allergen,
    SUM(pc.condition_count) AS total_conditions,
    SUM(pa.allergy_count) AS total_allergies
FROM 
    PatientAllergies pa
JOIN (
    SELECT 
        p.patient_id,
        COUNT(c.condition_id) AS condition_count
    FROM 
        patients p
    JOIN 
        conditions c ON c.patient_id = p.patient_id
    GROUP BY 
        p.patient_id
) pc ON pc.patient_id = pa.patient_id
GROUP BY 
    pa.race_ethnicity_name, pa.gender, pa.allergen;

-- Query 3: Investigate emergency visits and associated clinical notes
WITH EmergencyVisits AS (
    SELECT 
        vs.visit_id,
        vs.patient_id,
        vs.visit_date,
        vs.was_emergency
    FROM 
        visits vs
    WHERE 
        vs.was_emergency = TRUE
)
SELECT 
    ev.patient_id,
    ev.visit_date,
    COUNT(cn.note_id) AS note_count,
    ARRAY_AGG(cn.note_summary) AS note_summaries
FROM 
    EmergencyVisits ev
JOIN (
    SELECT 
        cn.visit_id,
        cn.note_id,
        cn.note_summary
    FROM 
        clinical_notes cn
    WHERE 
        cn.note_type = 'Summary'
) cn ON cn.visit_id = ev.visit_id
GROUP BY 
    ev.patient_id, ev.visit_date;

-- Query 4: Analyze payment sources by claim amount and claim status
WITH ClaimsData AS (
    SELECT 
        c.claim_id,
        c.patient_id,
        c.claim_amount,
        c.claim_status,
        COALESCE(SUM(p.amount), 0) AS total_payments
    FROM 
        claims c
    LEFT JOIN 
        payments p ON c.claim_id = p.claim_id
    GROUP BY 
        c.claim_id
),
PatientIncome AS (
    SELECT 
        i.patient_id,
        i.income_level,
        RANK() OVER (PARTITION BY i.patient_id ORDER BY i.recorded_date DESC) AS income_rank
    FROM 
        income_brackets i
)
SELECT 
    cd.claim_id,
    cd.claim_status,
    pi.income_level,
    SUM(CASE WHEN cd.claim_status = 'Paid' THEN cd.claim_amount ELSE 0 END) AS paid_claims
FROM 
    ClaimsData cd
JOIN 
    PatientIncome pi ON pi.patient_id = cd.patient_id AND pi.income_rank = 1
GROUP BY 
    cd.claim_id, cd.claim_status, pi.income_level;

-- Query 5: Calculate risk scores based on historical diagnoses
WITH PatientDiagnoses AS (
    SELECT 
        p.patient_id,
        d.diagnosis_code,
        d.diagnosis_date
    FROM 
        patients p
    JOIN 
        visits v ON v.patient_id = p.patient_id
    JOIN 
        diagnoses d ON d.visit_id = v.visit_id
),
RiskScoring AS (
    SELECT 
        pd.patient_id,
        pd.diagnosis_code,
        COUNT(pd.diagnosis_code) AS diagnosis_count
    FROM 
        PatientDiagnoses pd
    GROUP BY 
        pd.patient_id, pd.diagnosis_code
)
SELECT 
    rs.patient_id,
    rs.diagnosis_code,
    rs.diagnosis_count,
    r.score_value,
    CASE
        WHEN rs.diagnosis_count >= 5 THEN 'High Risk'
        WHEN rs.diagnosis_count BETWEEN 2 AND 4 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS risk_level
FROM 
    RiskScoring rs
JOIN 
    risk_scores r ON r.patient_id = rs.patient_id
WHERE 
    r.score_type = 'Health';

-- Query 6: Compare medication patterns across different providers
WITH MedicationData AS (
    SELECT 
        pr.provider_id,
        pr.specialty,
        m.medication_name,
        AVG(CASE WHEN m.start_date IS NOT NULL THEN 1 ELSE 0 END) AS avg_start_date_present
    FROM 
        providers pr
    JOIN 
        visits v ON v.provider_id = pr.provider_id
    JOIN 
        medications m ON m.visit_id = v.visit_id
    GROUP BY 
        pr.provider_id, pr.specialty, m.medication_name
),
ProviderSpecialties AS (
    SELECT 
        specialty,
        COUNT(DISTINCT provider_id) AS provider_count
    FROM 
        providers
    GROUP BY 
        specialty
)
SELECT 
    md.specialty,
    md.medication_name,
    AVG(md.avg_start_date_present) AS avg_start_date_present,
    ps.provider_count
FROM 
    MedicationData md
JOIN 
    ProviderSpecialties ps ON ps.specialty = md.specialty
GROUP BY 
    md.specialty, md.medication_name, ps.provider_count;

-- Query 7: Evaluate lab test utilization and results over time
WITH LabData AS (
    SELECT 
        l.visit_id,
        l.test_name,
        l.result_value,
        l.collected_date
    FROM 
        labs l
    WHERE 
        l.collected_date > CURRENT_DATE - INTERVAL '1 year'
),
YearlyLabResults AS (
    SELECT 
        ld.test_name,
        AVG(ld.result_value) AS avg_result,
        COUNT(ld.test_name) AS test_count
    FROM 
        LabData ld
    GROUP BY 
        ld.test_name
)
SELECT 
    ylr.test_name,
    ylr.avg_result,
    ylr.test_count,
    CASE 
        WHEN ylr.test_count > 500 THEN 'High Utilization'
        WHEN ylr.test_count BETWEEN 100 AND 500 THEN 'Medium Utilization'
        ELSE 'Low Utilization'
    END AS utilization_category
FROM 
    YearlyLabResults ylr;

-- Query 8: Track survey scores and resulting insights
WITH SurveyScores AS (
    SELECT 
        s.patient_id,
        s.survey_type,
        AVG(s.survey_score) AS avg_score
    FROM 
        surveys s
    GROUP BY 
        s.patient_id, s.survey_type
),
InsuranceData AS (
    SELECT 
        i.patient_id,
        COUNT(i.insurance_id) AS insurance_count
    FROM 
        insurance i
    GROUP BY 
        i.patient_id
)
SELECT 
    ss.survey_type,
    ss.avg_score,
    COUNT(id.insurance_count) AS insured_patients
FROM 
    SurveyScores ss
JOIN 
    InsuranceData id ON id.patient_id = ss.patient_id
GROUP BY 
    ss.survey_type, ss.avg_score
HAVING 
    COUNT(id.insurance_count) > 10;

-- Query 9: Explore employment status impact on healthcare utilization
WITH EmploymentData AS (
    SELECT 
        e.patient_id,
        e.employment_type,
        e.status_date
    FROM 
        employment_status e
    WHERE 
        e.status_date > CURRENT_DATE - INTERVAL '2 years'
),
VisitCounts AS (
    SELECT 
        v.patient_id,
        COUNT(v.visit_id) AS visit_count
    FROM 
        visits v
    GROUP BY 
        v.patient_id
)
SELECT 
    ed.employment_type,
    AVG(vc.visit_count) AS avg_visits,
    SUM(CASE WHEN ed.employment_type = 'Unemployed' THEN 1 ELSE 0 END) AS unemployed_count
FROM 
    EmploymentData ed
JOIN 
    VisitCounts vc ON vc.patient_id = ed.patient_id
GROUP BY 
    ed.employment_type;

-- Query 10: Assess impact of social determinants on patient risk scores
WITH SDOHData AS (
    SELECT 
        se.patient_id,
        se.sdoh_type,
        COUNT(se.sdoh_id) AS sdoh_count
    FROM 
        sdoh_entries se
    GROUP BY 
        se.patient_id, se.sdoh_type
),
PatientRisk AS (
    SELECT 
        rs.patient_id,
        AVG(rs.score_value) AS avg_risk_score
    FROM 
        risk_scores rs
    GROUP BY 
        rs.patient_id
)
SELECT 
    sd.sdoh_type,
    AVG(sd.sdoh_count) AS avg_sdoh_count,
    COUNT(pr.avg_risk_score) AS patients_with_risk,
    AVG(pr.avg_risk_score) AS avg_risk_score
FROM 
    SDOHData sd
JOIN 
    PatientRisk pr ON pr.patient_id = sd.patient_id
GROUP BY 
    sd.sdoh_type;