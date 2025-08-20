//
//  userActivityViewController.swift
//  RouteGen
//
//  Created by Shankar Singh on 6/7/2025.
//

import UIKit
import Charts
import FirebaseAuth
import HealthKit
import FirebaseFirestore
import DGCharts

class userActivityViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, ChartViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var stepsTotalLabel: UILabel!
    @IBOutlet weak var stepsGoalLabel: UILabel!
    @IBOutlet weak var caloriesTotalLabel: UILabel!
    @IBOutlet weak var caloriesGoalLabel: UILabel!
    @IBOutlet weak var stepsChartContainer: UIView!
    @IBOutlet weak var caloriesChartContainer: UIView!
    @IBOutlet weak var AddGoal: UIBarButtonItem!
    @IBOutlet weak var timeFrameButton: UIButton!

    // MARK: - Properties
    let repository = Repository()
    let healthStore = HKHealthStore()
    var currentTimeFrame: TimeFrame = .today
    var currentGoal: Goal?

    private let timeFramePicker = UIPickerView()
    private let timeFrames = TimeFrame.allCases
    private var timeFrameTextField: UITextField!

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd"
        return df
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTimeFrameDropdown()
        requestHealthKitPermission()
        fetchAndDisplay()
    }

    // MARK: - Setup Timeframe Dropdown
    private func setupTimeFrameDropdown() {
        timeFramePicker.delegate = self
        timeFramePicker.dataSource = self

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissPicker))
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneButton], animated: false)

        timeFrameTextField = UITextField(frame: .zero)
        timeFrameTextField.inputView = timeFramePicker
        timeFrameTextField.inputAccessoryView = toolbar
        timeFrameTextField.isHidden = true
        view.addSubview(timeFrameTextField)

        timeFrameButton.setTitle(currentTimeFrame.rawValue, for: .normal)
    }

    @IBAction func timeFrameButtonTapped(_ sender: UIButton) {
        timeFrameTextField.becomeFirstResponder()
    }

    @objc func dismissPicker() {
        view.endEditing(true)
        fetchAndDisplay()
    }

    // MARK: - PickerView Delegates
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { timeFrames.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { timeFrames[row].rawValue }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentTimeFrame = timeFrames[row]
        timeFrameButton.setTitle(currentTimeFrame.rawValue, for: .normal)
    }

    // MARK: - Goal Button
    @IBAction func setGoalsTapped(_ sender: UIBarButtonItem) {
        promptUserForGoals()
    }

    func promptUserForGoals() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        repository.fetchGoal(forUserId: userId) { [weak self] goal in
            self?.currentGoal = goal
            let alert = UIAlertController(title: "Set Daily Goals", message: "Enter your goals below (leave blank to keep existing)", preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "Daily Steps"; $0.keyboardType = .numberPad; $0.text = goal != nil ? String(goal!.dailySteps) : "" }
            alert.addTextField { $0.placeholder = "Daily Calories"; $0.keyboardType = .numberPad; $0.text = goal != nil ? String(goal!.dailyCalories) : "" }
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                let steps = Int(alert.textFields?[0].text ?? "") ?? goal?.dailySteps ?? 0
                let calories = Int(alert.textFields?[1].text ?? "") ?? goal?.dailyCalories ?? 0
                let updatedGoal = Goal(id: userId, dailySteps: steps, dailyCalories: calories, dailyDistanceKm: 0)
                self?.repository.saveOrUpdateGoal(withData: updatedGoal) { if $0 { DispatchQueue.main.async { self?.fetchAndDisplay() } } }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self?.present(alert, animated: true)
        }
    }

    // MARK: - HealthKit
    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKQuantityType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if success {
                DispatchQueue.main.async { self.fetchAndDisplay() }
            } else {
                print("❌ HealthKit auth failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    // MARK: - Fetch & Display
    private func fetchAndDisplay() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        repository.fetchGoal(forUserId: userId) { [weak self] goal in
            guard let self = self, let goal = goal else { return }
            self.currentGoal = goal
            self.fetchHealthDataFromHealthKit(for: self.currentTimeFrame) { dailyData in
                let totalSteps = dailyData.values.map { $0.steps }.reduce(0, +)
                let totalCalories = dailyData.values.map { $0.calories }.reduce(0, +)
                let goalSteps = Double(goal.dailySteps) * Double(self.currentTimeFrame.daysMultiplier)
                let goalCalories = Double(goal.dailyCalories) * Double(self.currentTimeFrame.daysMultiplier)

                let stepProgress = goalSteps > 0 ? (totalSteps / goalSteps) * 100 : 0
                let calProgress = goalCalories > 0 ? (totalCalories / goalCalories) * 100 : 0

                DispatchQueue.main.async {
                    self.stepsTotalLabel.text = "Total: \(Int(totalSteps)) steps (\(Int(stepProgress))%)"
                    self.stepsGoalLabel.text = "Goal: \(Int(goalSteps)) steps"
                    self.caloriesTotalLabel.text = "Total: \(Int(totalCalories)) kcal (\(Int(calProgress))%)"
                    self.caloriesGoalLabel.text = "Goal: \(Int(goalCalories)) kcal"
                    self.renderStepsChart(totalSteps: totalSteps, goalSteps: goalSteps)
                    self.renderCaloriesChart(totalCalories: totalCalories, goalCalories: goalCalories)
                }
                self.saveDailyDataToFirebase(dailyData: dailyData, userId: userId)
            }
        }
    }

    // MARK: - HealthKit Query
    private func fetchHealthDataFromHealthKit(for timeframe: TimeFrame, completion: @escaping ([Date: (steps: Double, calories: Double)]) -> Void) {
        let days = timeframe.daysMultiplier
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: 1 - days, to: Calendar.current.startOfDay(for: endDate))!
        let interval = DateComponents(day: 1)
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        func query(_ type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions, _ handler: @escaping ([Date: Double]) -> Void) {
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: nil, options: options, anchorDate: startDate, intervalComponents: interval)
            query.initialResultsHandler = { _, collection, _ in
                var results: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    results[stats.startDate] = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                handler(results)
            }
            healthStore.execute(query)
        }

        query(stepType, unit: .count(), options: .cumulativeSum) { stepsDaily in
            query(calorieType, unit: .kilocalorie(), options: .cumulativeSum) { caloriesDaily in
                var combined: [Date: (steps: Double, calories: Double)] = [:]
                for date in Set(stepsDaily.keys).union(caloriesDaily.keys) {
                    combined[date] = (stepsDaily[date] ?? 0, caloriesDaily[date] ?? 0)
                }
                completion(combined)
            }
        }
    }

    // MARK: - Save Daily Data + Adjust + Weekly/Monthly Totals
    private func saveDailyDataToFirebase(dailyData: [Date: (steps: Double, calories: Double)], userId: String) {
        let db = Firestore.firestore()
        let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyy-MM-dd"
        let weekFormatter = DateFormatter(); weekFormatter.dateFormat = "YYYY-'W'ww"
        let monthFormatter = DateFormatter(); monthFormatter.dateFormat = "yyyy-MM"

        for (date, data) in dailyData {
            let dateString = dateFormatter.string(from: date)
            let weekString = weekFormatter.string(from: date)
            let monthString = monthFormatter.string(from: date)

            let dailyRef = db.collection("User").document(userId).collection("metrics").document("healthMetrics").collection("daily").document(dateString)
            let newSteps = Int(data.steps); let newCalories = Int(data.calories)

            dailyRef.getDocument { snapshot, _ in
                let oldSteps = snapshot?.data()?["steps"] as? Int ?? 0
                let oldCalories = snapshot?.data()?["calories"] as? Int ?? 0

                dailyRef.setData(["steps": newSteps, "calories": newCalories], merge: true) { err in
                    if err != nil { return }
                    let stepsDiff = newSteps - oldSteps
                    let calDiff = newCalories - oldCalories
                    self.adjustTotal(for: userId, stepsDiff: stepsDiff, calDiff: calDiff)
                    self.adjustPeriodTotal(for: userId, periodType: "weekly", periodKey: weekString, stepsDiff: stepsDiff, calDiff: calDiff)
                    self.adjustPeriodTotal(for: userId, periodType: "monthly", periodKey: monthString, stepsDiff: stepsDiff, calDiff: calDiff)
                }
            }
        }
    }

    private func adjustTotal(for userId: String, stepsDiff: Int, calDiff: Int) {
        let ref = Firestore.firestore().collection("User").document(userId).collection("metrics").document("total")
        ref.getDocument { snap, _ in
            var s = snap?.data()?["totalSteps"] as? Int ?? 0
            var c = snap?.data()?["totalCalories"] as? Int ?? 0
            s += stepsDiff; c += calDiff
            ref.setData(["totalSteps": s, "totalCalories": c], merge: true)
        }
    }

    private func adjustPeriodTotal(for userId: String, periodType: String, periodKey: String, stepsDiff: Int, calDiff: Int) {
        let ref = Firestore.firestore()
            .collection("User")
            .document(userId)
            .collection("metrics")
            .document("healthMetrics")  // ✅ Inside healthMetrics
            .collection(periodType)     // "weekly" or "monthly"
            .document(periodKey)

        ref.getDocument { snap, _ in
            var s = snap?.data()?["steps"] as? Int ?? 0
            var c = snap?.data()?["calories"] as? Int ?? 0
            s += stepsDiff
            c += calDiff
            ref.setData(["steps": s, "calories": c], merge: true)
        }
    }


    // MARK: - Render Charts
    private func renderStepsChart(totalSteps: Double, goalSteps: Double) {
        setupBarChart(container: stepsChartContainer, total: totalSteps, goal: goalSteps, labelActual: "A = Actual Steps", labelGoal: "G = Goal Steps")
    }
    private func renderCaloriesChart(totalCalories: Double, goalCalories: Double) {
        setupBarChart(container: caloriesChartContainer, total: totalCalories, goal: goalCalories, labelActual: "A = Actual Calories", labelGoal: "G = Goal Calories")
    }

    private func setupBarChart(container: UIView, total: Double, goal: Double, labelActual: String, labelGoal: String) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let chart = BarChartView()
        chart.delegate = self
        chart.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chart)
        NSLayoutConstraint.activate([
            chart.topAnchor.constraint(equalTo: container.topAnchor),
            chart.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chart.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let actualEntry = BarChartDataEntry(x: 0, y: total)
        let goalEntry = BarChartDataEntry(x: 1, y: goal)

        let actualSet = BarChartDataSet(entries: [actualEntry], label: labelActual)
        actualSet.setColor(.systemRed)
        let goalSet = BarChartDataSet(entries: [goalEntry], label: labelGoal)
        goalSet.setColor(.systemBlue)

        let data = BarChartData(dataSets: [goalSet, actualSet])
        data.barWidth = 0.3
        data.groupBars(fromX: -0.5, groupSpace: 0.4, barSpace: 0.05)
        chart.data = data

        chart.rightAxis.enabled = false
        chart.leftAxis.axisMinimum = 0
        chart.legend.enabled = true
        chart.xAxis.drawLabelsEnabled = true
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values: ["A", "G"])
        chart.xAxis.granularity = 1
        chart.animate(yAxisDuration: 1.0, easingOption: .easeInCubic)
    }

    // MARK: - Chart Tap
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        let alert = UIAlertController(title: "Value", message: "\(Int(entry.y))", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - TimeFrame Enum
enum TimeFrame: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    var daysMultiplier: Int { self == .today ? 1 : self == .week ? 7 : 30 }
}
