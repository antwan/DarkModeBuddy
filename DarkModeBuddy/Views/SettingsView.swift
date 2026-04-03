//
//  SettingsView.swift
//  DarkModeBuddy
//
//  Created by Guilherme Rambo on 23/02/21.
//

import SwiftUI
import DarkModeBuddyCore

struct SettingsView: View {
    @EnvironmentObject var reader: DMBAmbientLightSensorReader
    @EnvironmentObject var settings: DMBSettings
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var timeScheduleManager: TimeScheduleManager

    private let darknessInterval: ClosedRange<Double> = 0...3000

    @State private var isShowingDarknessValueOutOfBoundsAlert = false
    @State private var isEditingAmbientLightLevelManually = false
    @State private var editingAmbientLightManuallyTextFieldStore = ""
    @State private var selectedTimeMode: TimeScheduleMode = .fixedTime

    private static let hourOptions = Array(0...23)
    private static let minuteOptions = [0, 15, 30, 45]

    var body: some View {
        Group {
            if reader.isSensorReady {
                settingsControls
            } else {
                UnsupportedMacView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding([.top, .bottom])
        .padding([.leading, .trailing], 22)
        .onAppear { reader.activate() }
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 32) {
            Toggle(
                "Launch at Login",
                isOn: $settings.isLaunchAtLoginEnabled
            )

            Toggle(
                "Change Theme Automatically",
                isOn: $settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled
            )

            Group {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Dark When Ambient Light Falls Below:")

                    HStack(alignment: .firstTextBaseline) {
                        Slider(value: $settings.darknessThreshold, in: darknessInterval)
                            .frame(maxWidth: 300)
                        if isEditingAmbientLightLevelManually {
                            TextField("", text: $editingAmbientLightManuallyTextFieldStore, onCommit: {
                                guard let newValue = Double(editingAmbientLightManuallyTextFieldStore),
                                      newValue >= darknessInterval.lowerBound,
                                      newValue <= darknessInterval.upperBound else {
                                    isShowingDarknessValueOutOfBoundsAlert = true
                                    return
                                }
                                settings.darknessThreshold = newValue
                                isEditingAmbientLightLevelManually = false
                            })
                            .frame(maxWidth: 40)
                        } else {
                            Text("\(settings.darknessThreshold.formattedNoFractionDigits)")
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .onTapGesture(count: 2) {
                                    self.editingAmbientLightManuallyTextFieldStore = "\(settings.darknessThreshold.formattedNoFractionDigits)"
                                    isEditingAmbientLightLevelManually = true
                                }
                        }
                    }
                    .alert(isPresented: $isShowingDarknessValueOutOfBoundsAlert) {
                        Alert(title: Text("Error"),
                              message: Text("The threshold value must be in the interval [\(darknessInterval.lowerBound.formattedNoFractionDigits), \(darknessInterval.upperBound.formattedNoFractionDigits)]"),
                              dismissButton: .default(Text("OK")))
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Current Ambient Light Level:")
                        Text("\(reader.ambientLightValue.formattedNoFractionDigits)")
                            .font(.system(size: 12).monospacedDigit())
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))


                    Text("Delay Time:")
                        .padding(.top, 22)

                    HStack(alignment: .firstTextBaseline) {
                        Slider(value: $settings.darknessThresholdIntervalInSeconds, in: 15...600, step: 15)
                        Text(settings.darknessThresholdIntervalInSeconds.formattedTime)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                // MARK: - Time Constraints Section

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Time constraints", isOn: timeConstraintsBinding)
                        .padding(.top, 16)

                    if settings.timeScheduleMode != .disabled {
                        Picker("Only change theme within:", selection: timeModePickerBinding) {
                            Text("Fixed time window").tag(TimeScheduleMode.fixedTime)
                            Text("Relative to sunset/sunrise").tag(TimeScheduleMode.solarRelative)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .padding(.leading, 8)

                        if selectedTimeMode == .fixedTime {
                            fixedTimeControls
                        }

                        if selectedTimeMode == .solarRelative {
                            solarRelativeControls
                        }
                    }
                }
            }
            .disabled(!settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled)

            Text(settings.currentSettingsDescription)
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
//                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }

    // MARK: - Time Constraints Bindings

    private var timeConstraintsBinding: Binding<Bool> {
        Binding(
            get: { settings.timeScheduleMode != .disabled },
            set: { enabled in
                if enabled {
                    settings.timeScheduleMode = selectedTimeMode
                } else {
                    settings.timeScheduleMode = .disabled
                }
            }
        )
    }

    private var timeModePickerBinding: Binding<TimeScheduleMode> {
        Binding(
            get: { selectedTimeMode },
            set: { newMode in
                selectedTimeMode = newMode
                if settings.timeScheduleMode != .disabled {
                    settings.timeScheduleMode = newMode
                }
            }
        )
    }

    // MARK: - Fixed Time Controls

    private var fixedTimeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack() {
                Text("Start:")
                    .frame(width: 35, alignment: .leading)
                Picker("", selection: $settings.fixedStartHour) {
                    ForEach(Self.hourOptions, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 60)
                Text(":")
                Picker("", selection: $settings.fixedStartMinute) {
                    ForEach(Self.minuteOptions, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 60)
            }

            HStack {
                Text("End:")
                    .frame(width: 35, alignment: .leading)
                Picker("", selection: $settings.fixedEndHour) {
                    ForEach(Self.hourOptions, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 60)
                Text(":")
                Picker("", selection: $settings.fixedEndMinute) {
                    ForEach(Self.minuteOptions, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 60)
            }
        }
        .padding(.leading, 8)
    }

    // MARK: - Solar Relative Controls

    private var solarRelativeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 6){
                        let startDropdown = Picker("", selection: $settings.sunsetOffsetMinutes) {
                            ForEach(SolarOffset.allCases) { offset in
                                Text(sunsetLabel(for: offset)).tag(offset.rawValue)
                            }
                        }
                        .frame(width: 180, alignment: .leading)

                        HStack {
                            Text("Start:").frame(width: 35, alignment: .leading)
                            if #available(macOS 26.0, *) {
                                startDropdown.buttonSizing(.flexible)
                            } else {
                                startDropdown
                            }
                        }
                        let endDropdown = Picker("", selection: $settings.sunriseOffsetMinutes) {
                            ForEach(SolarOffset.allCases) { offset in
                                Text(sunriseLabel(for: offset)).tag(offset.rawValue)
                            }
                        }
                        .frame(width: 180, alignment: .leading)

                        HStack {
                            Text("End:")
                                .frame(width: 35, alignment: .leading)
                            if #available(macOS 26.0, *) {
                                endDropdown.buttonSizing(.flexible)
                            } else {
                                endDropdown
                            }
                        }
                    }
                    if locationManager.hasLocation {
                        solarTimesDisplay
                    }

            }

            if !locationManager.hasLocation {
                HStack(spacing: 10) {
                    Text("\u{26A0} Location required for sunrise/sunset calculation.")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Button("Grant permission") {
                        locationManager.requestPermission()
                    }
                    .font(.system(size: 11))
                }.frame(height: 30, alignment: .trailing)
            }

            if let error = locationManager.locationError {
                Text("Location error: \(error)")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .padding(.leading, 8)
    }

    private var solarTimesDisplay: some View {
        VStack(alignment: .center, spacing: 13) {
            if let sunset = timeScheduleManager.computedSunset {
                HStack(spacing: 4) {
                    Text("Adjusted time:")
                    Text(sunset.formattedTime)
                        .fontWeight(.medium)
                }
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            if let sunrise = timeScheduleManager.computedSunrise {
                HStack(spacing: 4) {
                    Text("Adjusted time:")
                    Text(sunrise.formattedTime)
                        .fontWeight(.medium)
                }
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
        }
    }

    // MARK: - Helpers

    private func sunsetLabel(for offset: SolarOffset) -> String {
        switch offset.rawValue {
        case let v where v < 0: return "\(offset.label) before sunset"
        case 0: return "At sunset"
        default: return "\(offset.label) after sunset"
        }
    }

    private func sunriseLabel(for offset: SolarOffset) -> String {
        switch offset.rawValue {
        case let v where v < 0: return "\(offset.label) before sunrise"
        case 0: return "At sunrise"
        default: return "\(offset.label) after sunrise"
        }
    }
}

extension NumberFormatter {
    static let noFractionDigits: NumberFormatter = {
        let f = NumberFormatter()

        f.numberStyle = .decimal
        f.maximumFractionDigits = 0

        return f
    }()
}

extension Double {
    var formattedNoFractionDigits: String {
        NumberFormatter.noFractionDigits.string(from: NSNumber(value: self)) ?? "!!!"
    }
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        return (formatter.string(from: self) ?? "!!!" ) + "s"
    }
    var formattedLongTime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter.string(from: self) ?? "!!!"
    }
}

extension Date {
    var formattedTime: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: self)
    }
}

extension DMBSettings {
    var currentSettingsDescription: String {
        guard isChangeSystemAppearanceBasedOnAmbientLightEnabled else {
            return "Dark Mode will not be enabled automatically based on ambient light."
        }

        return "Dark Mode will be enabled when the ambient light stays below \(darknessThreshold.formattedNoFractionDigits) for over \(darknessThresholdIntervalInSeconds.formattedLongTime)."
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = DMBSettings(forPreview: true)
        let locMgr = LocationManager()
        let schedMgr = TimeScheduleManager(settings: settings, locationManager: locMgr)
        SettingsView()
            .frame(maxWidth: 385)
            .environmentObject(DMBAmbientLightSensorReader(frequency: .realtime))
            .environmentObject(settings)
            .environmentObject(locMgr)
            .environmentObject(schedMgr)
            .previewLayout(.sizeThatFits)
    }
}
