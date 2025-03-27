
WITH HighRiskPatients AS (
    SELECT patient_id, MAX(score_value) AS max_risk_score
    FROM risk_scores
    WHERE calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
    HAVING MAX(score_value) > 85
)
SELECT p.patient_id, p.first_name, p.last_name, rt.race_ethnicity_name, v.visit_date, COUNT(di.diagnosis_id) AS diagnosis_count,
       AVG(pr.result_value) AS avg_lab_result
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnoses di ON v.visit_id = di.visit_id
JOIN (SELECT visit_id, result_value FROM labs WHERE test_code IN ('A1C', 'LDL')) pr ON v.visit_id = pr.visit_id
JOIN race_ethnicity rt ON p.race_ethnicity_id = rt.race_ethnicity_id
WHERE p.patient_id IN (SELECT patient_id FROM HighRiskPatients)
GROUP BY p.patient_id, rt.race_ethnicity_name, v.visit_date
HAVING COUNT(di.diagnosis_id) > 2;


WITH ProcedureDetails AS (
    SELECT procedure_id, procedure_code, COUNT(procedure_id) AS procedure_count
    FROM procedures
    WHERE procedure_date > CURRENT_DATE - INTERVAL '2 years'
    GROUP BY procedure_id, procedure_code
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(pe.procedure_id) OVER (PARTITION BY p.patient_id) AS total_procedures,
       CASE WHEN em.employment_type = 'Unemployed' THEN 'High Risk' ELSE 'Low Risk' END AS risk_category
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN ProcedureDetails pe ON v.visit_id = pe.visit_id
JOIN employment_status em ON p.patient_id = em.patient_id
WHERE pe.procedure_count > 5;


WITH VitalAverages AS (
    SELECT visit_id, 
           AVG(heart_rate) OVER (PARTITION BY visit_id) AS avg_heart_rate,
           AVG(bmi) OVER (PARTITION BY visit_id) AS avg_bmi
    FROM vitals
)
SELECT p.patient_id, p.first_name, v.encounter_type_id, vt.avg_heart_rate, vt.avg_bmi, 
       COUNT(mi.medication_id) AS medications_count, 
       SUM(cl.claim_amount) AS total_claim_amount
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN VitalAverages vt ON v.visit_id = vt.visit_id
JOIN medications mi ON v.visit_id = mi.visit_id
JOIN claims cl ON p.patient_id = cl.patient_id AND v.visit_id = cl.visit_id
WHERE mi.start_date BETWEEN CURRENT_DATE - INTERVAL '1 year' AND CURRENT_DATE
GROUP BY p.patient_id, v.encounter_type_id, vt.avg_heart_rate, vt.avg_bmi
HAVING SUM(cl.claim_amount) > 5000;


WITH RecentSurveyScores AS (
    SELECT patient_id, MAX(survey_date) AS latest_survey_date
    FROM surveys
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, AVG(sc.survey_score) AS avg_survey_score,
       COUNT(distinct s.screening_id) AS screening_count,
       CASE WHEN r.score_value > 70 THEN 'Urgent' ELSE 'Normal' END AS risk_level
FROM patients p
JOIN surveys sc ON p.patient_id = sc.patient_id
JOIN screenings s ON p.patient_id = s.patient_id
JOIN risk_scores r ON p.patient_id = r.patient_id
JOIN RecentSurveyScores rs ON p.patient_id = rs.patient_id AND sc.survey_date = rs.latest_survey_date
WHERE s.result = 'Positive'
GROUP BY p.patient_id, r.score_value;


WITH FrequentVisitors AS (
    SELECT patient_id, COUNT(visit_id) AS visit_count
    FROM visits
    WHERE visit_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY patient_id
    HAVING COUNT(visit_id) > 10
)
SELECT p.patient_id, p.first_name, vis.location, SUM(diag.billable_amount) AS total_billable_amount,
       LAG(diag.diagnosis_date) OVER (PARTITION BY p.patient_id ORDER BY diag.diagnosis_date) AS previous_diagnosis_date
FROM patients p
JOIN visits vis ON p.patient_id = vis.patient_id
JOIN diagnoses diag ON vis.visit_id = diag.visit_id
WHERE p.patient_id IN (SELECT patient_id FROM FrequentVisitors)
GROUP BY p.patient_id, vis.location
ORDER BY total_billable_amount DESC;


WITH LabTestSummary AS (
    SELECT visit_id, test_name, MAX(result_value) AS max_result_value
    FROM labs
    WHERE is_critical = TRUE
    GROUP BY visit_id, test_name
)
SELECT v.visit_id, em.employer_name, SUM(co.paid_amount) AS total_paid_amount,
       CASE WHEN ls.max_result_value > 200 THEN 'High Alert' ELSE 'Normal' END AS alert_status,
       COALESCE(SUM(b.paid_amount), 0) AS total_billings
FROM visits v
JOIN LabTestSummary ls ON v.visit_id = ls.visit_id
JOIN employment_status em ON v.patient_id = em.patient_id
JOIN claims cl ON v.visit_id = cl.visit_id
JOIN payments co ON cl.claim_id = co.claim_id
LEFT JOIN billing b ON cl.claim_id = b.claim_id
GROUP BY v.visit_id, em.employer_name, alert_status;


WITH UpdatedInsurance AS (
    SELECT i.insurance_id, COUNT(p.patient_id) AS policy_count
    FROM insurance i
    JOIN patients p ON i.insurance_id = p.insurance_id
    WHERE i.expiration_date > CURRENT_DATE
    GROUP BY i.insurance_id
)
SELECT p.patient_id, p.first_name, COUNT(diag.diagnosis_type) AS diagnosis_count,
       iu.policy_count, 
       CASE WHEN iu.policy_count > 50 THEN 'High Membership' ELSE 'Low Membership' END AS membership_status
FROM patients p
JOIN visits vis ON p.patient_id = vis.patient_id
JOIN diagnoses diag ON vis.visit_id = diag.visit_id
JOIN UpdatedInsurance iu ON p.insurance_id = iu.insurance_id
WHERE diag.diagnosis_type = 'Chronic'
GROUP BY p.patient_id, iu.policy_count;


WITH EmergencyVisits AS (
    SELECT v.visit_id, v.visit_date
    FROM visits v
    WHERE v.was_emergency = TRUE
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(e.visit_id) AS emergency_visit_count,
       AVG(m.medication_cost) AS avg_medication_cost,
       CASE WHEN s.severity = 'Severe' THEN 'High Risk' ELSE 'Moderate Risk' END AS risk_assessment
FROM patients p
JOIN EmergencyVisits e ON p.patient_id = e.visit_id
JOIN medications m ON e.visit_id = m.visit_id
JOIN symptoms s ON e.visit_id = s.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name, s.severity;


WITH AllergyConditions AS (
    SELECT pa.patient_id, COUNT(al.allergy_id) AS allergy_count
    FROM patients pa
    JOIN allergies al ON pa.patient_id = al.patient_id
    GROUP BY pa.patient_id
), ActiveConditions AS (
    SELECT c.patient_id, COUNT(c.condition_id) AS active_condition_count
    FROM conditions c
    WHERE c.condition_status = 'Active'
    GROUP BY c.patient_id
)
SELECT p.patient_id, a.allergy_count, ac.active_condition_count,
       COUNT(b.billing_id) AS total_bills,
       CASE WHEN ac.active_condition_count > 5 THEN 'Complex' ELSE 'Simple' END AS case_complexity
FROM patients p
JOIN AllergyConditions a ON p.patient_id = a.patient_id
JOIN ActiveConditions ac ON p.patient_id = ac.patient_id
JOIN billing b ON b.claim_id IN (SELECT claim_id FROM claims WHERE patient_id = p.patient_id)
GROUP BY p.patient_id, a.allergy_count, ac.active_condition_count;


WITH HighBMIVisits AS (
    SELECT v.visit_id, 
           CASE WHEN vt.bmi > 30 THEN 'Obese' 
                WHEN vt.bmi >= 25 THEN 'Overweight' 
                ELSE 'Normal' END AS bmi_category
    FROM visits v
    JOIN vitals vt ON v.visit_id = vt.visit_id
)
SELECT p.patient_id, COUNT(hb.visit_id) AS high_bmi_visits,
       AVG(diag_count) AS avg_diagnosis_per_visit,
       CASE WHEN total_spending > 10000 THEN 'High Expense' ELSE 'Moderate' END AS expense_level
FROM patients p
JOIN (SELECT visit_id, COUNT(diagnosis_id) AS diag_count 
      FROM diagnoses 
      GROUP BY visit_id) d ON p.patient_id = d.visit_id
JOIN HighBMIVisits hb ON d.visit_id = hb.visit_id
JOIN claims cl ON d.visit_id = cl.visit_id
GROUP BY p.patient_id, bmi_category, total_spending
HAVING COUNT(hb.visit_id) > 1;