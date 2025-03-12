//
//  TimerView.swift
//  Timer
//
//  Created by Kristian Emil on 15/09/2024.
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(viewModel.isCountingDown ? .orange : .blue)
                    .overlay {
                        Circle()
                            .fill(.blue)
                            .scaleEffect(viewModel.isCountingDown ? 1.2 : 0.0)
                            .offset(y: geometry.size.height * 0.8)
                            .scaledToFill()
                        
                        Circle()
                            .fill(.orange)
                            .scaleEffect(viewModel.isCountingDown ? 0.0 : 1.2)
                            .offset(y: geometry.size.height * 0.8)
                            .scaledToFill()
                        
                    }
                    .animation(.bouncy(duration: 0.3), value: viewModel.isCountingDown)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                
                VStack(alignment: .center, spacing: geometry.size.height * 0.05) {
    // MARK: test
//                    Text(viewModel.currentTimeAsString())
                    HStack(alignment: .center) {
                        
                        if viewModel.isCountingDown && !viewModel.isRunning {
                        VStack {
                                Button {
                                    viewModel.adjustTime(by: -1000)
                                } label: {
                                    Text("–")
                                        .font(.custom("Stormfaze", size: geometry.size.width * 0.1))
                                }
                                .buttonRepeatBehavior(.enabled)
                                .disabled(viewModel.currentTime == 0)
                                .frame(width: geometry.size.width * 0.1, alignment: .center)
                            }
                        }
                            Text("\(formatTimeSeconds(viewModel.currentTime))")
                            .font(.custom("Stormfaze", size: geometry.size.width * 0.5))  // Set a consistent font size
                            .frame(width: geometry.size.width * 0.6, alignment: .center)  // Fixed width for seconds
                        
                        if viewModel.isCountingDown && !viewModel.isRunning {
                        VStack {
                                Button {
                                    viewModel.adjustTime(by: 1000)
                                    //                                viewModel.countdownTime += 1000
                                    //                                viewModel.currentTime += 1000
                                } label: {
                                    Text("+")
                                        .font(.custom("Stormfaze", size: geometry.size.width * 0.1))
                                }
                                .buttonRepeatBehavior(.enabled)
                            }
                        .frame(width: geometry.size.width * 0.1, alignment: .center)
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.75, alignment: .center)
                    
                    // Minutes and milliseconds display (scaling based on available width)
                    HStack(alignment: .firstTextBaseline, spacing: geometry.size.width * 0.08) {
                        
                        // Minute Text - Fix the width to ensure it stays static
                        Text("\(formatTimeMinutes(viewModel.currentTime)) m")
                            .font(.custom("Stormfaze", size: geometry.size.width * 0.08))
                            .frame(width: geometry.size.width * 0.24, alignment: .leading)  // Fixed width for minutes
                        
                        
                        // Millisecond Text - Fixed width to avoid shifting
                        Text("\(formatTimeMilliseconds(viewModel.currentTime)).") // ds is decisecond ( 1 / tenth of a second
                            .font(.custom("Stormfaze", size: geometry.size.width * 0.08))
                            .frame(width: geometry.size.width * 0.44, alignment: .trailing)  // Fixed width for milliseconds
                    }
                    .foregroundStyle(viewModel.isCountingDown ? .white : .black)
                    
                }
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .monospacedDigit()
                .padding(geometry.size.width * 0.05)
                .contentTransition(.numericText(countsDown: true))
                .animation(.linear(duration: 0.3), value: viewModel.currentTime)
                .foregroundStyle(viewModel.isCountingDown ? .black : .white)
            }
            .ignoresSafeArea()
        }
    }
    
    private func formatTimeMinutes(_ time: Int) -> String {
        let minutes = time / 60000  // 1 minute = 60,000 milliseconds
        return String(format: "%01d", minutes)
    }
    
    private func formatTimeSeconds(_ time: Int) -> String {
        let seconds = (time % 60000) / 1000  // Extract remaining seconds
        return String(format: "%01d", seconds)
    }
    
    private func formatTimeMilliseconds(_ time: Int) -> String {
        let milliseconds = time % 1000 / 100  // Show full milliseconds (000-999)
        return String(format: "%01d", milliseconds)
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel())
}
