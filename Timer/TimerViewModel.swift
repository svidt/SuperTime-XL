//
//  TimerViewModel.swift
//  Timer
//
//  Created by Kristian Emil on 16/09/2024.
//

import ActivityKit
import AVFoundation
import Foundation
import QuartzCore
import SwiftUI
import UserNotifications
import WidgetKit

class TimerViewModel: ObservableObject {
    @Published var currentTime: Int = 0  // Current time in milliseconds
    @Published var countdownTime: Int = 0  // Target time for countdown in milliseconds
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var isCountingDown: Bool = false  // True for countdown, false for stopwatch
    @Published var isMuted: Bool = false  // Mute toggle
    
    private var displayLink: CADisplayLink?
    private var startTime: Date? = nil
    private var elapsedTime: TimeInterval = 0  // Store elapsed time when paused
    private var lastUpdateTimestamp: TimeInterval = Date().timeIntervalSince1970
    
    // Audioplayer
    private var player: AVAudioPlayer?
    
    // Live Activity
    private var currentActivity: Activity<SuperTimeAttributes>?
    private var liveActivityTimer: DispatchSourceTimer?  // Timer for updating live activity every second
    private var lastSecondUpdated: Int = 0  // To track the last second value
    
    init() {
        // Configure audio session for background audio
        configureAudioSession()
    }
    
    // Start or stop the stopwatch based on current state
    func toggleStartStop() {
        if isRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    // Switch between stopwatch and countdown mode
    func toggleMode(isCountdown: Bool, countdownFrom milliseconds: Int? = nil) {
        isCountingDown = isCountdown

        if isCountingDown, let countdown = milliseconds {
            print("Debug 1: Adding \(countdown) milliseconds to countdown time")
            countdownTime = countdown // Add time instead of resetting it
            print("Debug 2: countdownTime is now \(countdownTime)")
            currentTime = countdown // Add time to the current timer value
            print("Debug 3: currentTime is now \(currentTime)")
        } else {
            // In stopwatch mode, reset countdownTime but keep currentTime running
            countdownTime = 0
        }

        // Ensure Live Activity updates immediately
        updateLiveActivity()

        // Resume or start the timer in the new mode
        provideHapticFeedback(for: .change)
    }
    
    // MARK: - Start Timer
    func startTimer() {
        if !isRunning {
            startTime = Date().addingTimeInterval(-elapsedTime)  // Adjust for paused time
            displayLink = CADisplayLink(target: self, selector: #selector(updateTime))
            displayLink?.preferredFramesPerSecond = 60  // Smooth in-app updates
            displayLink?.add(to: .main, forMode: .common)
            isRunning = true
            isPaused = false
            print("Current Time 1: \(currentTime)")
            
            provideHapticFeedback(for: .startStop)
            UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from locking
            print("Screen: ON")
            
            startLiveActivityTimer()  // Start the live activity timer
            
            startLiveActivity()
            print("Timer started, Live Activity initiated")
            
            // Update widget with RUNNING
            let currentTimeFormatted = currentTimeAsString()
            updateTimerData(timerValue: currentTimeFormatted, timerState: "running", timerMode: currentMode())
            
            if isCountingDown {
                scheduleNotification()
                
                // Update widget with RUNNING
                let currentTimeFormatted = currentTimeAsString()  // Assuming you have a method to format current time as string
                updateTimerData(timerValue: currentTimeFormatted, timerState: "running", timerMode: currentMode())
                print("-->\(currentTimeFormatted)")
                print("-->\(currentTime)")
                
                print("🏁 Current Time Formattet: \(currentTimeFormatted)")
            }
        }
    }
    
    // MARK: - Stop Timer
    func stopTimer() {
        if isRunning {
            displayLink?.invalidate()
            displayLink = nil
            elapsedTime = Date().timeIntervalSince(startTime ?? Date())  // Store elapsed time
            isRunning = false
            isPaused = true
            
            UIApplication.shared.isIdleTimerDisabled = false
            print("~Screen Always OFF~")
            
            provideHapticFeedback(for: .startStop)
            
            stopLiveActivityTimer()  // Stop live activity updates
            endLiveActivity()  // Ensure live activity reflects the stop state
            print("Timer stopped, Live Activity updated")
            
            // Update widget with PAUSED
            // Log to confirm stopping behavior
            let currentTimeFormatted = currentTimeAsString()
            print("Current time after stop: \(currentTimeFormatted)")
            updateTimerData(timerValue: currentTimeFormatted, timerState: "paused", timerMode: currentMode())
        } else {
            print("stopTimer() called, but timer was not running.")
        }
    }
    
    // Reset the timer
    func resetTime() {
        if currentTime != 0 {
            provideHapticFeedback(for: .reset)
            print("🏁 Current Time After Reset: \(currentTime)")
        }

        stopTimer()
        currentTime = isCountingDown ? countdownTime : 0  // Reset to 0 or countdown start
        elapsedTime = 0
        isPaused = false

        provideHapticFeedback(for: .reset)
        
        UIApplication.shared.isIdleTimerDisabled = false  // Allow screen to lock again
        print("Screen: OFF")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        endLiveActivity()
        
        // Update widget with STOPPED
        let currentTimeFormatted = currentTimeAsString()
        updateTimerData(timerValue: currentTimeFormatted, timerState: "stopped", timerMode: currentMode())
    }
    
    // MARK: - Time Update
    @objc private func updateTime() {
        
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime) * 1000  // Elapsed time in ms
   
        if isCountingDown {
            updateCountdownTimer(elapsed: elapsed)
        } else {
            currentTime = Int(elapsed)  // Count up in stopwatch mode
        }
        
        // Ensure that we do not keep running if timer is stopped
        if !isRunning {
            print("updateTime() called but timer is no longer running.")
            return
        }
    }
    
    private func updateCountdownTimer(elapsed: TimeInterval) {
        let remainingTime = max(0, countdownTime - Int(elapsed))

        currentTime = remainingTime
        if remainingTime > 0 {
            updateLiveActivity()  // Ensure Live Activity updates
        } else {
            print("Countdown reached zero. Stopping timer.")
            
            stopTimer()
            endLiveActivity()
            stopLiveActivityTimer()
            
            UIApplication.shared.isIdleTimerDisabled = false
            print("Screen: OFF")
            playAlarm()
            print("Countdown reached zero, triggering alarm.")

            let currentTimeFormatted = currentTimeAsString()
            print("Timer stopped, time zeroed: \(currentTimeFormatted)")
            updateTimerData(timerValue: currentTimeFormatted, timerState: "stopped", timerMode: currentMode())
            
            updateLiveActivity()  // 🔥 Ensure UI updates even when time is 0!
        }
    }
    
    
    // MARK: - Play alarm sound
    func playAlarm() {
        if isMuted {
            print("Alarm is muted.")
            return  // Do not play the sound if muted
        }

        guard let soundURL = Bundle.main.url(forResource: "sound", withExtension: "wav") else {
            print("Alarm sound file not found.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: soundURL)
            player?.play()
            provideHapticFeedback(for: .ending)
            print("Alarm sound played successfully.")
        } catch {
            print("Error playing alarm sound: \(error.localizedDescription)")
        }
    }
    

    // MARK: - Audio Session Configuration for Background Playback
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers/*, .duckOthers*/])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session configured successfully for background playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Live Activity Management
    // Start or update live activity with start date
    func startLiveActivity() {
        guard currentActivity == nil else { return }

        if isCountingDown {
            // Countdown mode: Calculate end time
            let endDate = Date().addingTimeInterval(TimeInterval(countdownTime / 1000))
            let attributes = SuperTimeAttributes(timerType: "Countdown")
            let contentState = SuperTimeAttributes.ContentState(startDate: Date(), endDate: endDate, isRunning: true)

            let content = ActivityContent(state: contentState, staleDate: nil)

            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                print("Countdown live activity started. ID: \(currentActivity?.id ?? "unknown")")
            } catch {
                print("Failed to start countdown live activity: \(error)")
            }
        } else {
            // Stopwatch mode: Calculate start date
            let elapsedSeconds = currentTime / 1000
            let startDate = Date().addingTimeInterval(TimeInterval(-elapsedSeconds))

            let attributes = SuperTimeAttributes(timerType: "Stopwatch")
            let contentState = SuperTimeAttributes.ContentState(startDate: startDate, endDate: Date(), isRunning: true)

            let content = ActivityContent(state: contentState, staleDate: nil)

            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                print("Stopwatch live activity started. ID: \(currentActivity?.id ?? "unknown")")
            } catch {
                print("Failed to start stopwatch live activity: \(error)")
            }
        }
    }
    
    private func startLiveActivityTimer() {
        let queue = DispatchQueue(label: "com.supertime.liveactivity")
        liveActivityTimer = DispatchSource.makeTimerSource(queue: queue)
        liveActivityTimer?.schedule(deadline: .now(), repeating: 1.0)  // Update every second
        
        liveActivityTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let secondsElapsed = self.currentTime / 1000  // Convert to seconds

            if secondsElapsed != self.lastSecondUpdated {
                self.lastSecondUpdated = secondsElapsed
                DispatchQueue.main.async {
                    self.updateLiveActivity()  // Only update Live Activity every second
                }
            }
        }
        
        liveActivityTimer?.resume()
    }
    
    private func stopLiveActivityTimer() {
        if let timer = liveActivityTimer {
            timer.cancel()
            liveActivityTimer = nil
            print("Live activity timer stopped.")
        } else {
            print("No live activity timer to stop.")
        }
    }

    func updateLiveActivity() {
        guard let currentActivity = currentActivity else { return }

        let currentTimestamp = Date().timeIntervalSince1970  // Get current time in seconds
        // Determine if one second has passed since last update
        if currentTimestamp - lastUpdateTimestamp >= 1 {
            lastUpdateTimestamp = currentTimestamp  // Update the last update timestamp

            if isCountingDown {
                // Countdown mode updates
                let remainingSeconds = currentTime / 1000
                let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))

                let updatedState = SuperTimeAttributes.ContentState(
                    startDate: Date(), endDate: endDate, isRunning: isRunning
                )

                let updatedContent = ActivityContent(state: updatedState, staleDate: nil)
                print("Updating countdown live activity. Time left (s): \(remainingSeconds)")

                Task {
                    await currentActivity.update(updatedContent)
                }

            } else {
                // Stopwatch mode updates
                let elapsedSeconds = currentTime / 1000
                let startDate = Date().addingTimeInterval(TimeInterval(-elapsedSeconds))

                let updatedState = SuperTimeAttributes.ContentState(
                    startDate: startDate, endDate: Date(), isRunning: isRunning
                )

                let updatedContent = ActivityContent(state: updatedState, staleDate: nil)

                print("Updating stopwatch live activity. Elapsed time (s): \(elapsedSeconds)")

                Task {
                    await currentActivity.update(updatedContent)
                }
            }
        }
    }
    

    func endLiveActivity() {
        guard let currentActivity = currentActivity else {
            print("No live activity to end.")
            return
        }
        
        Task {
            let finalState = SuperTimeAttributes.ContentState(
                startDate: Date(),  // Placeholder, as it's the end state
                endDate: Date(),    // The time when the activity ended
                isRunning: false
            )

            let finalContent = ActivityContent(state: finalState, staleDate: nil)

            await currentActivity.end(finalContent, dismissalPolicy: .immediate)
            self.currentActivity = nil  // Clear the reference to the ended activity
            
            // Update widget with PAUSED
            let currentTimeFormatted = currentTimeAsString()
            print("Live activity ended, current time: \(currentTimeFormatted)")
            updateTimerData(timerValue: currentTimeFormatted, timerState: "paused", timerMode: currentMode())
            
        }
    }
    
    
    // MARK: - Notification permission
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleNotification() {
        // Ensure that we have a positive time interval for the notification
        let timeInterval = TimeInterval(currentTime / 1000)
        guard timeInterval > 0 else {
            print("Invalid time interval for notification, must be greater than 0.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "Your countdown timer has reached zero."
        content.sound = .default
        
        // Trigger the notification after the countdown time
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(identifier: "timerNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    
    //MARK: - Haptic feedback
    func provideHapticFeedback(for action: HapticAction) {
        switch action {
        case .startStop:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .reset:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .change:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .ending:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .mistake:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    
    // MARK: - Widget
    func updateTimerData(timerValue: String, timerState: String, timerMode: String) {
        let sharedDefaults = UserDefaults(suiteName: "group.supertime")
        sharedDefaults?.set(timerValue, forKey: "timerValue")
        sharedDefaults?.set(timerState, forKey: "timerState")
        sharedDefaults?.set(timerMode, forKey: "timerMode")
//        sharedDefaults?.synchronize()  // This forces UserDefaults to save the data immediately
        WidgetCenter.shared.reloadAllTimelines()  // Ensure the widget is updated immediately after changes
        print("Widget Updated: \(timerState)")
    }
    
    private var lastFormattedTime: (time: Int, string: String)?

    func currentTimeAsString() -> String {
        if let cached = lastFormattedTime, cached.time == currentTime {
            return cached.string
        }
        let seconds = currentTime / 1000
        let minutes = seconds / 60
        let hours = minutes / 60
        let formattedTime = String(format: "%02d:%02d:%02d", hours, minutes % 60, seconds % 60)
        lastFormattedTime = (currentTime, formattedTime)
        return formattedTime
    }
    
    func currentMode() -> String {
        return isCountingDown ? "timer" : "stopwatch"
    }
    
    
    func adjustTime(by milliseconds: Int) {
        if isCountingDown {
            // Don't allow negative time
            if milliseconds < 0 && currentTime < abs(milliseconds) {
                return
            }
            countdownTime += milliseconds
            currentTime += milliseconds            
            
            // If the timer is running, we need to adjust the start time
            if isRunning {
                startTime = Date().addingTimeInterval(-TimeInterval(countdownTime - currentTime) / 1000)
            }
            
            // Update live activity if needed
            updateLiveActivity()
            
            // Update widget
            let currentTimeFormatted = currentTimeAsString()
            updateTimerData(timerValue: currentTimeFormatted, timerState: "running", timerMode: currentMode())
        }
    }
    
}

enum HapticAction {
    case startStop
    case reset
    case change
    case ending
    case mistake
}
