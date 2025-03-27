WITH LatestAddresses AS (
    SELECT 
        patient_id, 
        address_id, 
        MAX(updated_at) AS MaxDate
    FROM 
        patients
    GROUP BY 
        patient_id, address_id
),
AverageVitals AS (
    SELECT
        visit_id,
        AVG(heart_rate) OVER (PARTITION BY visit_id) AS avg_heart_rate,
        AVG(bmi) OVER (PARTITION BY visit_id) AS avg_bmi
    FROM 
        vitals
)
SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name AS full_name,
    COALESCE(d.diagnosis_description, 'No Diagnosis') AS primary_diagnosis,
    AVG(v.weight_kg) AS avg_weight,
    SUM(CASE WHEN v.heart_rate > 100 THEN 1 ELSE 0 END) AS high_heart_rate_count
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    (SELECT * FROM diagnoses WHERE diagnosis_type = 'primary') d ON v.visit_id = d.visit_id
JOIN 
    LatestAddresses la ON p.patient_id = la.patient_id
LEFT JOIN 
    AverageVitals av ON v.visit_id = av.visit_id
WHERE 
    v.was_emergency = TRUE
GROUP BY 
    p.patient_id, full_name, primary_diagnosis
HAVING 
    COUNT(v.visit_id) > 1;


WITH MonthlyMedicationCounts AS (
    SELECT 
        patient_id,
        COUNT(medication_id) AS med_count,
        EXTRACT(MONTH FROM start_date) AS med_month
    FROM 
        medications
    GROUP BY 
        patient_id, med_month
),
FilteredPatients AS (
    SELECT 
        patient_id
    FROM 
        income_brackets
    WHERE 
        income_level = 'low'
)
SELECT 
    p.patient_id,
    COUNT(v.visit_id) AS visit_count,
    MIN(m.med_month) AS first_med_month,
    MAX(cm.med_count) AS max_med_count_in_month,
    CASE WHEN MIN(m.med_month) < 6 THEN 'First Half' ELSE 'Second Half' END AS half_of_year
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    MonthlyMedicationCounts m ON p.patient_id = m.patient_id
LEFT JOIN 
    FilteredPatients fp ON p.patient_id = fp.patient_id
JOIN 
    (SELECT * FROM conditions WHERE condition_name = 'Diabetes') cd ON p.patient_id = cd.patient_id
JOIN 
    claims cl ON v.visit_id = cl.visit_id
GROUP BY 
    p.patient_id;


WITH SDOHImpact AS (
    SELECT 
        patient_id,
        sdoh_type,
        COUNT(sdoh_id) AS sdoh_count
    FROM 
        sdoh_entries
    GROUP BY 
        patient_id, sdoh_type
),
RiskScoreChanges AS (
    SELECT 
        patient_id,
        score_value - LAG(score_value, 1) OVER (PARTITION BY patient_id ORDER BY calculated_date) AS score_change
    FROM 
        risk_scores
)
SELECT 
    p.patient_id,
    r1.race_ethnicity_name,
    ls.language_name,
    AVG(rs.score_change) AS avg_score_change,
    MAX(sd.sdoh_count) AS max_sdoh_count,
    CASE WHEN AVG(rs.score_change) > 5 THEN 'High Risk Increase' ELSE 'Low Risk Increase' END AS risk_category
FROM 
    patients p
JOIN 
    race_ethnicity r1 ON p.race_ethnicity_id = r1.race_ethnicity_id
JOIN 
    languages ls ON p.language_id = ls.language_id
JOIN 
    RiskScoreChanges rs ON p.patient_id = rs.patient_id
LEFT JOIN 
    SDOHImpact sd ON p.patient_id = sd.patient_id
WHERE 
    EXISTS (SELECT 1 FROM conditions c WHERE p.patient_id = c.patient_id AND c.condition_status = 'active')
GROUP BY 
    p.patient_id, r1.race_ethnicity_name, ls.language_name;


WITH EmergencyVisits AS (
    SELECT 
        visit_id, 
        patient_id, 
        COUNT(*) OVER (PARTITION BY patient_id) AS em_visit_count
    FROM 
        visits 
    WHERE 
        was_emergency = TRUE
),
HighBillingAmounts AS (
    SELECT 
        claim_id, 
        claim_amount
    FROM 
        claims
    WHERE 
        claim_amount > 1000
)
SELECT 
    p.patient_id,
    COUNT(ev.visit_id) AS total_emergency_visits,
    SUM(hb.claim_amount) AS total_high_billing
FROM 
    patients p
JOIN 
    EmergencyVisits ev ON p.patient_id = ev.patient_id
JOIN 
    claims cl ON ev.visit_id = cl.visit_id
JOIN 
    HighBillingAmounts hb ON cl.claim_id = hb.claim_id
WHERE 
    p.gender = 'Female'
GROUP BY 
    p.patient_id;


WITH RecentScreeningResults AS (
    SELECT 
        patient_id,
        screening_type,
        result,
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY screening_date DESC) AS rn
    FROM 
        screenings
)
SELECT 
    p.patient_id,
    COUNT(DISTINCT v.visit_id) AS visit_count,
    MAX(rs.result) FILTER (WHERE rs.rn = 1) AS most_recent_screening_result,
    CASE WHEN ct.team_name IS NOT NULL THEN 'Part of Care Team' ELSE 'Not Assigned' END AS care_team_status
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    RecentScreeningResults rs ON p.patient_id = rs.patient_id
LEFT JOIN 
    patient_care_team pct ON p.patient_id = pct.patient_id
LEFT JOIN 
    care_teams ct ON pct.care_team_id = ct.care_team_id
LEFT JOIN 
    clinical_notes cn ON v.visit_id = cn.visit_id
WHERE 
    EXTRACT(YEAR FROM v.visit_date) = 2022
GROUP BY 
    p.patient_id, care_team_status;


WITH LatestLabs AS (
    SELECT 
        visit_id, 
        MAX(reported_date) AS RecentLabDate
    FROM 
        labs
    GROUP BY 
        visit_id
),
VisitProcedures AS (
    SELECT 
        visit_id,
        STRING_AGG(DISTINCT procedure_code, ', ') AS procedure_list
    FROM 
        procedures
    GROUP BY 
        visit_id
)
SELECT 
    p.patient_id,
    AVG(l.result_value) AS avg_lab_value,
    COUNT(DISTINCT l.test_name) AS distinct_test_count,
    vp.procedure_list
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    LatestLabs ll ON v.visit_id = ll.visit_id
JOIN 
    labs l ON v.visit_id = l.visit_id AND l.reported_date = ll.RecentLabDate
JOIN 
    VisitProcedures vp ON v.visit_id = vp.visit_id
WHERE 
    v.location IN (SELECT DISTINCT location FROM providers WHERE specialty = 'Cardiology')
GROUP BY 
    p.patient_id, vp.procedure_list;


WITH AllergyDetails AS (
    SELECT 
        patient_id, 
        COUNT(allergy_id) AS total_allergies
    FROM 
        allergies
    GROUP BY 
        patient_id
),
ActiveEmployment AS (
    SELECT 
        patient_id,
        employer_name
    FROM 
        employment_status
    WHERE 
        employment_type = 'Full-Time' AND status_date > CURRENT_DATE - INTERVAL '1 year'
)
SELECT 
    p.patient_id,
    COALESCE(ae.employer_name, 'Unemployed') AS employment_status,
    ad.total_allergies,
    CASE WHEN ad.total_allergies > 5 THEN 'High Allergy' ELSE 'Low Allergy' END AS allergy_risk
FROM 
    patients p
LEFT JOIN 
    ActiveEmployment ae ON p.patient_id = ae.patient_id
LEFT JOIN 
    AllergyDetails ad ON p.patient_id = ad.patient_id
JOIN 
    (SELECT * FROM claims WHERE claim_status = 'approved') cl ON p.patient_id = cl.patient_id
JOIN 
    (SELECT * FROM visits WHERE visit_date > CURRENT_DATE - INTERVAL '1 year') v ON cl.visit_id = v.visit_id
GROUP BY 
    p.patient_id, employment_status, ad.total_allergies;


WITH ImagingSummary AS (
    SELECT 
        visit_id,
        COUNT(imaging_id) AS imaging_count,
        STRING_AGG(DISTINCT imaging_type, ', ') AS imaging_types
    FROM 
        imaging
    GROUP BY 
        visit_id
),
FrequentlyScreenedPatients AS (
    SELECT 
        patient_id,
        COUNT(screening_id) AS screening_count
    FROM 
        screenings
    WHERE 
        EXTRACT(YEAR FROM screening_date) = 2022
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    COUNT(v.visit_id) AS visit_total,
    im.imaging_types,
    SUM(fsp.screening_count) AS total_screenings_2022
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    ImagingSummary im ON v.visit_id = im.visit_id
LEFT JOIN 
    FrequentlyScreenedPatients fsp ON p.patient_id = fsp.patient_id
LEFT JOIN 
    insurance i ON p.insurance_id = i.insurance_id AND i.plan_type = 'Medicare'
WHERE 
    p.gender = 'Male' AND v.was_emergency = FALSE
GROUP BY 
    p.patient_id, im.imaging_types, fsp.screening_count;


WITH CountedLanguages AS (
    SELECT 
        language_id, 
        COUNT(patient_id) AS language_count
    FROM 
        patients
    GROUP BY 
        language_id
),
CommunityRiskScores AS (
    SELECT 
        patient_id,
        AVG(score_value) AS avg_risk_score
    FROM 
        risk_scores
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    rl.race_ethnicity_name,
    cl.language_count,
    crs.avg_risk_score,
    CASE 
        WHEN crs.avg_risk_score > 7 THEN 'High Risk' 
        ELSE 'Low Risk' 
    END AS risk_level
FROM 
    patients p
JOIN 
    CommunityRiskScores crs ON p.patient_id = crs.patient_id
JOIN 
    race_ethnicity rl ON p.race_ethnicity_id = rl.race_ethnicity_id
LEFT JOIN 
    CountedLanguages cl ON p.language_id = cl.language_id
WHERE 
    EXISTS (SELECT 1 FROM conditions WHERE patient_id = p.patient_id AND condition_status = 'chronic')
GROUP BY 
    p.patient_id, rl.race_ethnicity_name, cl.language_count, crs.avg_risk_score;


WITH ProviderSpecialityCounts AS (
    SELECT 
        specialty, 
        COUNT(provider_id) AS total_providers
    FROM 
        providers
    GROUP BY 
        specialty
),
PatientScreeningResults AS (
    SELECT 
        patient_id,
        STRING_AGG(DISTINCT result, ', ') AS screening_results
    FROM 
        screenings
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    psr.screening_results,
    COUNT(v.visit_id) AS visit_count,
    MAX(psc.total_providers) AS max_providers_specialty
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    PatientScreeningResults psr ON p.patient_id = psr.patient_id
LEFT JOIN 
    ProviderSpecialityCounts psc ON EXISTS (
        SELECT 1 FROM providers pr WHERE v.provider_id = pr.provider_id AND pr.specialty = psc.specialty
    )
JOIN 
    (SELECT * FROM vitals WHERE recorded_at > CURRENT_DATE - INTERVAL '1 year') vt ON v.visit_id = vt.visit_id
WHERE 
    v.encounter_type_id IN (SELECT encounter_type_id FROM encounter_types WHERE encounter_type_name = 'Inpatient')
GROUP BY 
    p.patient_id, psr.screening_results;
