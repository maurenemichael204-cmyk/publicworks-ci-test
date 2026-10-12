import XCTest

/// PublicWorks 自己UID版 —— 云端模拟器 UI 回归测试。
/// 前置：CI 已在宿主 127.0.0.1:8443 起好 TLS Mock，并已把 cert.pem 加入模拟器信任。
final class PublicWorksUITests: XCTestCase {

    private var app: XCUIApplication!

    private let validURL = "https://127.0.0.1:8443/v1"
    private let goodToken = "dev-only-token"
    private let myUID = "my_own_uid_001"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
        }
        app = nil
    }

    // MARK: - 工具

    private func dismissKeyboardIfNeeded() {
        guard app.keyboards.count > 0 else { return }
        // 优先点键盘的确认/返回键；找不到就整页下滑收起键盘。
        // （早前写的 app.press(.key(.RETURN)) 和 swipeDown(orientation:) 都不是本 SDK 的 API，编译失败）
        for label in ["return", "Return", "done", "Done", "go", "Go"] {
            let key = app.keyboards.buttons[label]
            if key.exists { key.tap(); break }
        }
        if app.keyboards.count > 0 {
            app.swipeDown()
        }
    }

    private func set(_ field: XCUIElement, _ text: String, backspaces: Int = 0) {
        field.tap()
        let deletes = max(backspaces, (field.value as? String)?.count ?? 0)
        if deletes > 0 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deletes))
        }
        if !text.isEmpty {
            field.typeText(text)
        }
        dismissKeyboardIfNeeded()
    }

    private func assertText(_ substring: String,
                            timeout: TimeInterval = 15,
                            context: String = "") {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let element = app.staticTexts.matching(predicate).firstMatch
        app.swipeDown(); app.swipeDown()          // 回到页面顶部
        if element.waitForExistence(timeout: 4) { return }
        // 逐级下滑并等待懒渲染；若找到则返回，找不到则每级留档可见文本
        for depth in 0..<6 {
            app.swipeUp()
            if element.waitForExistence(timeout: 2) {
                print("UI-DEBUG[\(context)] found at scroll depth \(depth)")
                return
            }
            let labels = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            print("UI-DEBUG[\(context)] depth=\(depth) labels=\(labels)")
        }
        XCTAssertTrue(false, "界面应出现「\(substring)」（\(context)）")
    }

    private func ensureVisible(_ element: XCUIElement) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
    }

    private func tapButton(identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "找不到按钮 \(identifier)")
        ensureVisible(button)
        button.tap()
    }

    // MARK: - 主回归流程

    func testFullFlow() throws {
        // 0. 打开日志开关（用于断言"配置已保存"等日志文本）
        let logToggle = app.switches["启用日志"]
        XCTAssertTrue(logToggle.waitForExistence(timeout: 15), "找不到日志开关")
        ensureVisible(logToggle)
        // 注意：SwiftUI 开关的 value 可能是 NSNumber 而非 String，
        // `as? String` 会得到 nil —— 前几轮就是栽在这，tap 从未执行。
        let before = "\(logToggle.value ?? "nil")"
        print("UI-DEBUG toggle value before = \(before)")
        if before != "1" { logToggle.tap() }
        let after = "\(logToggle.value ?? "nil")"
        print("UI-DEBUG toggle value after  = \(after)")
        XCTAssertEqual(after, "1", "「启用日志」开关必须处于打开状态，日志区才会渲染")
        dismissKeyboardIfNeeded()

        let baseURLField = app.textFields["baseURLField"]
        let tokenField = app.secureTextFields["tokenField"]
        let uidField = app.textFields["uidField"]

        // 1. http:// 开头的 Base URL 应被拒绝
        set(baseURLField, "http://insecure.example.com")
        set(tokenField, goodToken)
        set(uidField, myUID)
        tapButton(identifier: "saveButton")
        assertText("必须是有效的 HTTPS 地址", context: "http 校验")

        // 2. 改成合法 HTTPS，但 Token 清空 → 报 Token 不能为空
        set(baseURLField, validURL, backspaces: "http://insecure.example.com".count)
        set(tokenField, "", backspaces: goodToken.count)
        tapButton(identifier: "saveButton")
        assertText("Token 不能为空", context: "空 Token 校验")

        // 3. Token 填回，UID 清空 → 报 UID 校验
        set(tokenField, goodToken)
        set(uidField, "", backspaces: myUID.count)
        tapButton(identifier: "saveButton")
        assertText("UID 不能为空", context: "空 UID 校验")

        // 3b. 非法字符 UID → 同样被拦截
        set(uidField, "非法UID!")
        tapButton(identifier: "saveButton")
        assertText("仅限字母", context: "UID 白名单校验")

        // 4. 全部合法 → 保存成功（日志区出现"配置已保存"）
        set(uidField, myUID, backspaces: "非法UID!".count)
        tapButton(identifier: "saveButton")
        assertText("配置已保存", context: "保存成功")

        // 5. 立即查询 → 出现虚构作品（TLS 网络 + 模拟器证书信任链路）
        tapButton(identifier: "refreshButton")
        assertText("虚构的测试作品一", timeout: 30, context: "查询成功结果")
        assertText("查询时间", context: "查询时间戳")

        // 6. 旧版必崩场景：连点两次立即查询（并发防护回归）
        let refreshButton = app.buttons["refreshButton"]
        ensureVisible(refreshButton)
        refreshButton.tap()
        if refreshButton.isEnabled { refreshButton.tap() } // 禁用=互斥生效；可点则=快速重入
        assertText("虚构的测试作品一", timeout: 15, context: "并发连点后仍稳定")
        XCTAssertEqual(app.state, .runningForeground, "App 应保持前台存活")

        // 7. 换错误 Token → 查询区应报 401
        set(tokenField, "wrong-token", backspaces: goodToken.count)
        tapButton(identifier: "saveButton")
        tapButton(identifier: "refreshButton")
        assertText("服务器返回 HTTP 401", timeout: 30, context: "401 错误展示")

        // 8. 清除本地数据 → 结果清空、字段清空
        tapButton(identifier: "clearButton")
        assertText("暂无查询结果", context: "清除后无结果")
        XCTAssertEqual(baseURLField.value as? String, "", "Base URL 应被清空")
    }
}
