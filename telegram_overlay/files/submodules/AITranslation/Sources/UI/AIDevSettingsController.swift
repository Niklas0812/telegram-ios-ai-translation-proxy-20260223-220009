import Foundation
#if canImport(UIKit) && canImport(Display) && canImport(AsyncDisplayKit)
import UIKit
import Display
import AsyncDisplayKit

public final class AIDevSettingsController: ViewController {
    private let rootNode = ASDisplayNode()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let contextModeControl = UISegmentedControl(items: ["Single", "Context"])
    private let countLabel = UILabel()
    private let countStepper = UIStepper()
    private let rawResponsesToggle = UISwitch()
    
    public override init(navigationBarPresentationData: NavigationBarPresentationData? = nil) {
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        self.title = "AI Translation Dev Settings"
    }
    
    public required init(coder: NSCoder) {
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
        
        self.stackView.axis = .vertical
        self.stackView.spacing = 12.0
        self.scrollView.addSubview(self.stackView)
        
        self.stackView.addArrangedSubview(Self.sectionHeader("Translation Context"))
        self.contextModeControl.addTarget(self, action: #selector(self.contextModeChanged), for: .valueChanged)
        self.stackView.addArrangedSubview(self.contextModeControl)
        
        let contextHint = UILabel()
        contextHint.numberOfLines = 0
        contextHint.font = UIFont.systemFont(ofSize: 13.0)
        contextHint.textColor = .secondaryLabel
        contextHint.text = "Single = current message only. Context = include recent messages for better coherence."
        self.stackView.addArrangedSubview(contextHint)
        
        self.stackView.addArrangedSubview(Self.sectionHeader("Context Message Count"))
        self.countLabel.font = UIFont.systemFont(ofSize: 17.0)
        self.countLabel.textColor = .label
        self.stackView.addArrangedSubview(self.countLabel)
        
        self.countStepper.minimumValue = 2
        self.countStepper.maximumValue = 100
        self.countStepper.stepValue = 1
        self.countStepper.addTarget(self, action: #selector(self.countChanged), for: .valueChanged)
        self.stackView.addArrangedSubview(self.countStepper)
        
        self.stackView.addArrangedSubview(Self.sectionHeader("Debug"))
        self.stackView.addArrangedSubview(Self.makeToggleRow(title: "Show Raw API Responses", toggle: self.rawResponsesToggle))
        self.rawResponsesToggle.addTarget(self, action: #selector(self.rawResponsesChanged), for: .valueChanged)
        
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
    
    @objc private func contextModeChanged() {
        let selected = self.contextModeControl.selectedSegmentIndex == 1 ? AITranslationContextMode.conversationContext : .singleMessage
        AITranslationConfig.shared.update { settings in
            settings.contextMode = selected
        }
        self.reloadFromConfig()
    }
    
    @objc private func countChanged() {
        let count = Int(self.countStepper.value.rounded())
        AITranslationConfig.shared.update { settings in
            settings.contextMessageCount = max(2, min(100, count))
        }
        self.reloadFromConfig()
    }
    
    @objc private func rawResponsesChanged() {
        AITranslationConfig.shared.update { settings in
            settings.showRawAPIResponses = self.rawResponsesToggle.isOn
        }
        self.reloadFromConfig()
    }
    
    private func reloadFromConfig() {
        let settings = AITranslationConfig.shared.load()
        self.contextModeControl.selectedSegmentIndex = settings.contextMode == .conversationContext ? 1 : 0
        self.countStepper.value = Double(max(2, min(100, settings.contextMessageCount)))
        self.countLabel.text = "Recent messages sent as context: \(Int(self.countStepper.value))"
        self.rawResponsesToggle.isOn = settings.showRawAPIResponses
        
        let contextEnabled = settings.contextMode == .conversationContext
        self.countLabel.alpha = contextEnabled ? 1.0 : 0.4
        self.countStepper.isEnabled = contextEnabled
        self.countStepper.alpha = contextEnabled ? 1.0 : 0.4
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
