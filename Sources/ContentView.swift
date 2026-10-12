import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section("服务器配置") {
                    TextField("HTTPS Base URL", text: $model.baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("baseURLField")

                    SecureField("Bearer Token", text: $model.token)
                        .accessibilityIdentifier("tokenField")

                    TextField("自己的 UID", text: $model.uid)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("uidField")

                    Stepper(
                        "轮询间隔：\(model.pollMinutes) 分钟",
                        value: $model.pollMinutes,
                        in: 1...1440
                    )

                    Button("保存配置") {
                        model.saveConfiguration()
                    }
                    .accessibilityIdentifier("saveButton")

                    if let error = model.configurationError {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section("查询") {
                    HStack {
                        Button("立即查询") {
                            Task { await model.refreshOnce() }
                        }
                        .disabled(model.isRefreshing)
                        .accessibilityIdentifier("refreshButton")

                        Spacer()

                        Button(model.isRunning ? "停止自动查询" : "开始自动查询") {
                            model.isRunning ? model.stop() : model.start()
                        }
                        .accessibilityIdentifier("startStopButton")
                    }

                    if model.isRefreshing {
                        Text("正在查询…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = model.runtimeError {
                        Text("查询错误：\(error)")
                            .foregroundColor(.red)
                    }

                    Toggle("启用日志", isOn: $model.loggingEnabled)
                }

                Section("我的公开作品") {
                    if model.items.isEmpty {
                        Text("暂无查询结果")
                            .foregroundColor(.secondary)
                    }

                    ForEach(model.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UID：\(item.uid)")
                                .font(.headline)

                            if let error = item.error {
                                Text("失败原因：\(error)")
                                    .foregroundColor(.red)
                            } else {
                                Text("查询时间：\(item.fetchedAt)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(item.works) { work in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(work.title)
                                        Text("发布时间：\(work.publishedAt)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let url = URL(string: work.url),
                                           url.scheme == "https" {
                                            Link("打开作品", destination: url)
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.vertical, 3)
                                }

                                if item.works.isEmpty {
                                    Text("没有返回公开作品")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if model.loggingEnabled {
                    Section("本次运行日志（不持久化）") {
                        ForEach(model.logs) { entry in
                            Text("\(entry.time.formatted())  \(entry.message)")
                                .font(.caption)
                        }
                    }
                }

                Section {
                    Button("清除本地配置、Token 和结果", role: .destructive) {
                        model.clearLocalData()
                    }
                    .accessibilityIdentifier("clearButton")
                }
            }
            .navigationTitle("我的公开作品")
        }
    }
}
