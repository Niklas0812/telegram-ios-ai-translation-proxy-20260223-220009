import Foundation
#if canImport(UIKit) && canImport(Display) && canImport(AsyncDisplayKit)
import UIKit
import Display
import AsyncDisplayKit

public final class AISettingsController: ViewController {
    private let rootNode = ASDisplayNode()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let globalToggle = UISwitch()
    private let incomingToggle = UISwitch()
    private let outgoingToggle = UISwitch()
    private let rawResponsesToggle = UISwitch()
    
    private let proxyURLField = UITextField()
    private let connectionStatusLabel = UILabel()
    private let testConnectionButton = UIButton(type: .system)
    private let applyProxyURLButton = UIButton(type: .system)
    private let devSettingsButton = UIButton(type: .system)
    
    private var isTestingConnection = false
    
    public override init(navigationBarPresentationData: NavigationBarPresentationData? = nil) {
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        self.title = "AI Translation"
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadDisplayNode() {
        self.rootNode.backgroundColor = .systemBackground
        self.displayNode = self.rootNode
        self.displayNodeDidLoad()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.largeTitleDisplayMode = .never
        self.displayNode.view.addSubview(self.scrollView)
        
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .onDrag
        
        self.stackView.axis = .vertical
        self.stackView.spacing = 12.0
        self.scrollView.addSubview(self.stackView)
        
        self.stackView.addArrangedSubview(Self.sectionHeader("Main Settings"))
        self.stackView.addArrangedSubview(Self.makeToggleRow(title: "Global Master Toggle", toggle: self.globalToggle))
        self.stackView.addArrangedSubview(Self.makeToggleRow(title: "Translate Incoming Messages", toggle: self.incomingToggle))
        self.stackView.addArrangedSubview(Self.makeToggleRow(title: "Translate Outgoing Messages", toggle: self.outgoingToggle))
        self.stackView.addArrangedSubview(Self.makeToggleRow(title: "Show Raw API Responses", toggle: self.rawResponsesToggle))
        
        for toggle in [self.globalToggle, self.incomingToggle, self.outgoingToggle, self.rawResponsesToggle] {
            toggle.addTarget(self, action: #selector(self.toggleChanged), for: .valueChanged)
        }
        
        self.stackView.addArrangedSubview(Self.sectionHeader("Proxy Server"))
        
        let proxyLabel = UILabel()
        proxyLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        proxyLabel.textColor = .secondaryLabel
        proxyLabel.text = "Proxy Server URL"
        self.stackView.addArrangedSubview(proxyLabel)
        
        self.proxyURLField.borderStyle = .roundedRect
        self.proxyURLField.placeholder = "https://your-tunnel-url.trycloudflare.com"
        self.proxyURLField.autocapitalizationType = .none
        self.proxyURLField.autocorrectionType = .no
        self.proxyURLField.keyboardType = .URL
        self.proxyURLField.returnKeyType = .done
        self.proxyURLField.clearButtonMode = .whileEditing
        self.proxyURLField.addTarget(self, action: #selector(self.proxyEditingEnded), for: .editingDidEnd)
        self.proxyURLField.addTarget(self, action: #selector(self.proxyEditingEnded), for: .editingDidEndOnExit)
        self.stackView.addArrangedSubview(self.proxyURLField)
        
        let cloudflareHintLabel = UILabel()
        cloudflareHintLabel.font = UIFont.systemFont(ofSize: 13.0)
        cloudflareHintLabel.textColor = .secondaryLabel
        cloudflareHintLabel.numberOfLines = 0
        cloudflareHintLabel.text = "Paste your current Cloudflared tunnel URL here (for example: https://abc123.trycloudflare.com). You can also paste a full /translate URL; the app will normalize it."
        self.stackView.addArrangedSubview(cloudflareHintLabel)
        
        self.applyProxyURLButton.setTitle("Apply Proxy URL", for: .normal)
        self.applyProxyURLButton.addTarget(self, action: #selector(self.applyProxyURLPressed), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.applyProxyURLButton)
        
        self.connectionStatusLabel.font = UIFont.systemFont(ofSize: 14.0)
        self.connectionStatusLabel.textColor = .secondaryLabel
        self.connectionStatusLabel.text = "Connection Status: Unknown"
        self.stackView.addArrangedSubview(self.connectionStatusLabel)
        
        self.testConnectionButton.setTitle("Test Connection", for: .normal)
        self.testConnectionButton.addTarget(self, action: #selector(self.testConnectionPressed), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.testConnectionButton)
        
        self.devSettingsButton.setTitle("Open Dev Settings", for: .normal)
        self.devSettingsButton.addTarget(self, action: #selector(self.openDevSettingsPressed), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.devSettingsButton)
        
        self.reloadFromConfig()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let bounds = self.displayNode.bounds
        self.scrollView.frame = bounds
        
        let inset: CGFloat = 16.0
        let width = max(0.0, bounds.width - inset * 2.0)
        self.stackView.frame = CGRect(x: inset, y: inset, width: width, height: 0.0)
        let fitted = self.stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        self.stackView.frame.size.height = fitted.height
        self.scrollView.contentSize = CGSize(width: bounds.width, height: max(bounds.height + 1.0, self.stackView.frame.maxY + inset))
    }
    
    @objc private func toggleChanged() {
        self.saveSettings()
        self.reloadFromConfig()
    }
    
    @objc private func proxyEditingEnded() {
        self.saveSettings()
    }
    
    @objc private func applyProxyURLPressed() {
        self.view.endEditing(true)
        self.saveSettings()
        self.reloadFromConfig()
        self.connectionStatusLabel.text = "Connection Status: Proxy URL updated"
        self.connectionStatusLabel.textColor = .secondaryLabel
    }
    
    @objc private func testConnectionPressed() {
        guard !self.isTestingConnection else {
            return
        }
        self.isTestingConnection = true
        self.testConnectionButton.isEnabled = false
        self.connectionStatusLabel.text = "Connection Status: Testing..."
        self.connectionStatusLabel.textColor = .secondaryLabel
        
        Task { [weak self] in
            guard let self else { return }
            let ok = await AITranslationService.shared.testConnection()
            DispatchQueue.main.async {
                self.isTestingConnection = false
                self.testConnectionButton.isEnabled = true
                self.connectionStatusLabel.text = "Connection Status: " + (ok ? "Connected" : "Failed")
                self.connectionStatusLabel.textColor = ok ? .systemGreen : .systemRed
            }
        }
    }
    
    @objc private func openDevSettingsPressed() {
        let controller = AIDevSettingsController()
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.pushViewController(controller)
        } else {
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    private func reloadFromConfig() {
        let settings = AITranslationConfig.shared.load()
        self.globalToggle.isOn = settings.globalEnabled
        self.incomingToggle.isOn = settings.translateIncomingEnabled
        self.outgoingToggle.isOn = settings.translateOutgoingEnabled
        self.rawResponsesToggle.isOn = settings.showRawAPIResponses
        self.incomingToggle.isEnabled = settings.globalEnabled
        self.outgoingToggle.isEnabled = settings.globalEnabled
        if self.proxyURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines) != settings.proxyBaseURL {
            self.proxyURLField.text = settings.proxyBaseURL
        }
    }
    
    private func saveSettings() {
        let proxyURL = Self.normalizeProxyBaseURL(self.proxyURLField.text ?? "")
        AITranslationConfig.shared.update { settings in
            settings.globalEnabled = self.globalToggle.isOn
            settings.translateIncomingEnabled = self.incomingToggle.isOn
            settings.translateOutgoingEnabled = self.outgoingToggle.isOn
            settings.showRawAPIResponses = self.rawResponsesToggle.isOn
            settings.proxyBaseURL = proxyURL
        }
    }
    
    private static func normalizeProxyBaseURL(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return ""
        }
        if !value.contains("://") {
            value = "https://" + value
        }
        guard var components = URLComponents(string: value) else {
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if components.path == "/translate" || components.path == "/health" || components.path == "/stats" {
            components.path = ""
        }
        components.query = nil
        components.fragment = nil
        let normalized = components.string ?? value
        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    private static func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13.0, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = text.uppercased()
        return label
    }
    
    private static func makeToggleRow(title: String, toggle: UISwitch) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 17.0)
        titleLabel.textColor = .label
        titleLabel.text = title
        titleLabel.numberOfLines = 0
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let row = UIStackView(arrangedSubviews: [titleLabel, spacer, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12.0
        return row
    }
}
#endif
