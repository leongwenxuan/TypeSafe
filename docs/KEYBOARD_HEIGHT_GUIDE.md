## TypeSafe Keyboard: Controlling Keyboard Height (and Banner Reserve)

This notes how we reliably increase a custom iOS keyboard’s height, probe device caps, and keep a top reserve for a banner/toolbar.

### TL;DR
- Make Auto Layout own the input view: `view.translatesAutoresizingMaskIntoConstraints = false`.
- Drive height in `updateViewConstraints()` with a REQUIRED height constraint.
- iOS may clamp to a host-defined cap; probe with a large value, then set what you want.
- Reserve banner space by anchoring the keyboard content (`keyboardView`) below `view.topAnchor` with a constant offset (e.g., 40pt).

### Live code (current)
- Required height set in `updateViewConstraints()`:
```158:169:/Users/leongwenxuan/Desktop/TypeSafe/TypeSafeKeyboard/KeyboardViewController.swift
override func updateViewConstraints() {
    // Set a desired total keyboard height; host may clamp smaller on some devices
    if heightConstraint == nil {
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 320)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    } else {
        heightConstraint?.constant = 320
        heightConstraint?.priority = .required
    }
    super.updateViewConstraints()
}
```

- Reserve 40pt at the top for banner/toolbar; keyboard content fills the rest:
```240:246:/Users/leongwenxuan/Desktop/TypeSafe/TypeSafeKeyboard/KeyboardViewController.swift
// Setup constraints for keyboard view (positioned below banner area)
NSLayoutConstraint.activate([
    keyboardView.leftAnchor.constraint(equalTo: view.leftAnchor),
    keyboardView.rightAnchor.constraint(equalTo: view.rightAnchor),
    keyboardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40), // reserve 40pt for banner/toolbar
    keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
])
```

### How to probe the device cap
1) Temporarily set the required height to something big (e.g., 1000pt) in `updateViewConstraints()`.
2) Add a tiny debug label that prints `view.bounds.height` in `viewDidLayoutSubviews`.
3) Open your keyboard in the host app; the printed value is the real cap on that device/orientation.

Minimal snippet for the label:
```swift
// in viewDidLoad
let l = UILabel()
l.font = .systemFont(ofSize: 12, weight: .semibold)
l.textColor = .red
l.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(l)
NSLayoutConstraint.activate([
    l.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
    l.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6)
])
debugHeightLabel = l

// in viewDidLayoutSubviews
debugHeightLabel?.text = String(format: "KB %.1fpt", view.bounds.height)
```

### Common gotchas
- Setting height in `viewWillLayoutSubviews` at priority 999 can be overridden by the host. Use `.required` in `updateViewConstraints()`.
- Always call `super.updateViewConstraints()` after touching constraints.
- The system fixes width to the screen width; height is up to your constraints but may be clamped by the host.
- If you reserve a banner area (e.g., 40pt), your keys will be shorter unless you increase the total height accordingly.

### Recommended workflow
1) Probe with 1000pt to learn the cap.
2) Set desired required height (e.g., cap or slightly below) in `updateViewConstraints()`.
3) Keep `keyboardView.topAnchor = view.topAnchor + bannerReserve` if you need a static banner/toolbar area.
4) Tune row sizes to utilize the available height; use internal scrolling for anything beyond the cap.


