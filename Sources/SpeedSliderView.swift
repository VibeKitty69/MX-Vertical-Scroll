import AppKit

class SpeedSliderView: NSView {
    private let titleLabel  = NSTextField(labelWithString: "Scroll Speed")
    private let valueLabel  = NSTextField(labelWithString: "")
    private let slider      = NSSlider()
    var onChanged: ((Double) -> Void)?

    static let viewWidth:  CGFloat = 280
    static let viewHeight: CGFloat = 50

    init(value: Double) {
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: Self.viewWidth,
                                 height: Self.viewHeight))
        setup(initialValue: value)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup(initialValue: Double) {
        let pad: CGFloat = 14

        // Title
        titleLabel.font = NSFont.menuFont(ofSize: 13)
        titleLabel.textColor = .labelColor

        // Value (e.g. "2.0×")
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.stringValue = Self.format(initialValue)

        // Slider
        slider.minValue   = 0.5
        slider.maxValue   = 10.0
        slider.doubleValue = initialValue
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)

        // Frames (y=0 is bottom in flipped=false NSView)
        let topRowY: CGFloat = Self.viewHeight - 20
        titleLabel.frame = NSRect(x: pad, y: topRowY, width: 130, height: 16)
        valueLabel.frame = NSRect(x: Self.viewWidth - pad - 50, y: topRowY, width: 50, height: 16)
        // Extend slider to full width — NSSlider adds its own knob inset internally
        slider.frame     = NSRect(x: 6, y: 6, width: Self.viewWidth - 12, height: 22)

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(slider)
    }

    @objc private func sliderMoved() {
        valueLabel.stringValue = Self.format(slider.doubleValue)
        onChanged?(slider.doubleValue)
    }

    var currentValue: Double { slider.doubleValue }

    func setValue(_ v: Double) {
        slider.doubleValue = v
        valueLabel.stringValue = Self.format(v)
    }

    static func format(_ v: Double) -> String { String(format: "%.1f×", v) }
}
