/* @ds-bundle: {"format":4,"namespace":"BlytheSLifeDesignSystem_420b07","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Chip","sourcePath":"components/core/Chip.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"ListRow","sourcePath":"components/core/ListRow.jsx"},{"name":"AmountField","sourcePath":"components/forms/AmountField.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"TextField","sourcePath":"components/forms/TextField.jsx"},{"name":"TimeField","sourcePath":"components/forms/TimeField.jsx"},{"name":"Sheet","sourcePath":"components/navigation/Sheet.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"Toast","sourcePath":"components/navigation/Toast.jsx"},{"name":"DraftCard","sourcePath":"components/tracking/DraftCard.jsx"},{"name":"EVENT_TYPES","sourcePath":"components/tracking/EventIcon.jsx"},{"name":"EventIcon","sourcePath":"components/tracking/EventIcon.jsx"},{"name":"EventRow","sourcePath":"components/tracking/EventRow.jsx"},{"name":"GlanceStat","sourcePath":"components/tracking/GlanceStat.jsx"},{"name":"NapCard","sourcePath":"components/tracking/NapCard.jsx"},{"name":"NursingTimer","sourcePath":"components/tracking/NursingTimer.jsx"},{"name":"QuickTile","sourcePath":"components/tracking/QuickTile.jsx"},{"name":"BlythesLifeApp","sourcePath":"ui_kits/ios/BlythesLifeApp.jsx"},{"name":"BASE_NOW","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"SCHEDULE","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"INITIAL_EVENTS","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"DRAFTS","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"LogSheet","sourcePath":"ui_kits/ios/LogSheet.jsx"},{"name":"PhoneFrame","sourcePath":"ui_kits/ios/PhoneFrame.jsx"},{"name":"RhythmScreen","sourcePath":"ui_kits/ios/RhythmScreen.jsx"},{"name":"SheetsScreen","sourcePath":"ui_kits/ios/ScanScreens.jsx"},{"name":"ReviewScreen","sourcePath":"ui_kits/ios/ScanScreens.jsx"},{"name":"SettingsScreen","sourcePath":"ui_kits/ios/SettingsScreen.jsx"},{"name":"TodayScreen","sourcePath":"ui_kits/ios/TodayScreen.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"55220cc26995","components/core/Button.jsx":"4b8eafbe7da5","components/core/Card.jsx":"0df25cc1194e","components/core/Chip.jsx":"c6e567c47aae","components/core/Icon.jsx":"f847faf06b87","components/core/IconButton.jsx":"160ae86166c7","components/core/ListRow.jsx":"207aa35991a5","components/forms/AmountField.jsx":"3d372389d6fa","components/forms/Checkbox.jsx":"3367c5fcf86b","components/forms/SegmentedControl.jsx":"400751e87212","components/forms/Switch.jsx":"1f833bbfa6f3","components/forms/TextField.jsx":"10228f5400c8","components/forms/TimeField.jsx":"2485896804a2","components/navigation/Sheet.jsx":"600d81769a48","components/navigation/TabBar.jsx":"a2834ec8394c","components/navigation/Toast.jsx":"14d1b29f980f","components/tracking/DraftCard.jsx":"aef06daf1004","components/tracking/EventIcon.jsx":"de70fd271ee6","components/tracking/EventRow.jsx":"6e4807dc5f4f","components/tracking/GlanceStat.jsx":"b95fcceed87e","components/tracking/NapCard.jsx":"3518351e46a3","components/tracking/NursingTimer.jsx":"d0417c716398","components/tracking/QuickTile.jsx":"87d5c3296d39","ui_kits/ios/BlythesLifeApp.jsx":"53e7ff1c668f","ui_kits/ios/KitData.jsx":"e4ff115c16b9","ui_kits/ios/LogSheet.jsx":"240f06f88f0b","ui_kits/ios/PhoneFrame.jsx":"a4c23277181b","ui_kits/ios/RhythmScreen.jsx":"d64a59d64ffd","ui_kits/ios/ScanScreens.jsx":"bb910f37c791","ui_kits/ios/SettingsScreen.jsx":"746d73384004","ui_kits/ios/TodayScreen.jsx":"df5806e3a43c"},"inlinedExternals":[],"unexposedExports":[{"name":"clock","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"dur","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"fromHM","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"mmss","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"nurseSecs","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"range","sourcePath":"ui_kits/ios/KitData.jsx"},{"name":"toHM","sourcePath":"ui_kits/ios/KitData.jsx"}]} */

(() => {

const __ds_ns = (window.BlytheSLifeDesignSystem_420b07 = window.BlytheSLifeDesignSystem_420b07 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Card({
  tone = 'surface',
  flush,
  onClick,
  className = '',
  children,
  ...rest
}) {
  const cls = 'bl-card bl-card--' + tone + (flush ? ' bl-card--flush' : '') + (onClick ? ' is-pressable' : '') + ' ' + className;
  if (onClick) return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: cls,
    onClick: onClick
  }, rest), children);
  return /*#__PURE__*/React.createElement("div", _extends({
    className: cls
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Icon({
  name,
  size = 20,
  className = '',
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("i", _extends({
    "aria-hidden": "true",
    className: 'icon-' + name + ' bl-icon ' + className,
    style: {
      fontSize: size,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function Badge({
  tone = 'neutral',
  event,
  icon,
  className = '',
  children
}) {
  const cls = 'bl-badge ' + (event ? 'bl-badge--event bl-ev--' + event : 'bl-badge--' + tone) + ' ' + className;
  return /*#__PURE__*/React.createElement("span", {
    className: cls
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 12
  }) : null, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Button({
  variant = 'primary',
  size = 'md',
  icon,
  block,
  className = '',
  children,
  ...rest
}) {
  const cls = 'bl-btn bl-btn--' + variant + ' bl-btn--' + size + (block ? ' bl-btn--block' : '') + ' ' + className;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: cls
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === 'sm' ? 16 : size === 'lg' ? 22 : 20
  }) : null, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Chip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Chip({
  selected,
  size = 'md',
  icon,
  className = '',
  children,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-pressed": !!selected,
    className: 'bl-chip bl-chip--' + size + (selected ? ' is-selected' : '') + ' ' + className
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 16
  }) : null, children);
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Chip.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function IconButton({
  icon,
  label,
  variant = 'plain',
  size = 'md',
  className = '',
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    className: 'bl-iconbtn bl-iconbtn--' + variant + ' bl-iconbtn--' + size + ' ' + className
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === 'lg' ? 26 : 22
  }));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/ListRow.jsx
try { (() => {
function ListRow({
  icon,
  label,
  detail,
  value,
  trailing,
  chevron,
  danger,
  onClick,
  className = ''
}) {
  const Tag = onClick ? 'button' : 'div';
  return /*#__PURE__*/React.createElement(Tag, {
    type: onClick ? 'button' : undefined,
    className: 'bl-row' + (danger ? ' bl-row--danger' : '') + ' ' + className,
    onClick: onClick
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 20
  }) : null, /*#__PURE__*/React.createElement("span", {
    className: "bl-row__main"
  }, /*#__PURE__*/React.createElement("span", null, label), detail ? /*#__PURE__*/React.createElement("span", {
    className: "bl-row__detail"
  }, detail) : null), value != null ? /*#__PURE__*/React.createElement("span", {
    className: "bl-row__value"
  }, value) : null, trailing, chevron ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 18,
    className: "bl-row__chev"
  }) : null);
}
Object.assign(__ds_scope, { ListRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/ListRow.jsx", error: String((e && e.message) || e) }); }

// components/forms/AmountField.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function AmountField({
  value = '',
  onChange,
  unit,
  size = 'lg',
  placeholder = '0',
  ...rest
}) {
  const len = Math.max(String(value).length, String(placeholder).length, 1);
  const handle = e => {
    const v = e.target.value.replace(',', '.');
    if (/^\d*\.?\d*$/.test(v) && onChange) onChange(v);
  };
  return /*#__PURE__*/React.createElement("label", {
    className: 'bl-amount bl-amount--' + size
  }, /*#__PURE__*/React.createElement("input", _extends({
    className: "bl-amount__input",
    inputMode: "decimal",
    value: value,
    placeholder: placeholder,
    style: {
      width: len + 0.3 + 'ch'
    },
    onChange: handle
  }, rest)), unit ? /*#__PURE__*/React.createElement("span", {
    className: "bl-amount__unit"
  }, unit) : null);
}
Object.assign(__ds_scope, { AmountField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/AmountField.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Checkbox({
  checked,
  onChange,
  label,
  sub,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    role: "checkbox",
    "aria-checked": !!checked,
    className: "bl-check",
    onClick: () => onChange && onChange(!checked)
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "bl-check__box"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 16
  })), label ? /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("span", null, label), sub ? /*#__PURE__*/React.createElement("span", {
    className: "bl-check__sub"
  }, sub) : null) : null);
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function SegmentedControl({
  options = [],
  value,
  onChange,
  size = 'md',
  block,
  className = '',
  ...rest
}) {
  const opts = options.map(o => o && typeof o === 'object' ? o : {
    value: o,
    label: o
  });
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "radiogroup",
    className: 'bl-seg bl-seg--' + size + (block ? ' bl-seg--block' : '') + ' ' + className
  }, rest), opts.map(o => /*#__PURE__*/React.createElement("button", {
    key: String(o.value),
    type: "button",
    role: "radio",
    "aria-checked": o.value === value,
    className: 'bl-seg__opt' + (o.value === value ? ' is-selected' : ''),
    onClick: () => onChange && onChange(o.value)
  }, o.label)));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Switch({
  checked,
  onChange,
  label,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    role: "switch",
    "aria-checked": !!checked,
    "aria-label": label,
    className: "bl-switch",
    onClick: () => onChange && onChange(!checked)
  }, rest));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/forms/TextField.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function TextField({
  label,
  value,
  onChange,
  multiline,
  rows = 3,
  className = '',
  ...rest
}) {
  const Tag = multiline ? 'textarea' : 'input';
  return /*#__PURE__*/React.createElement("label", {
    className: 'bl-field ' + className
  }, label ? /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, label) : null, /*#__PURE__*/React.createElement(Tag, _extends({
    className: "bl-field__input",
    value: value,
    rows: multiline ? rows : undefined,
    onChange: e => onChange && onChange(e.target.value)
  }, rest)));
}
Object.assign(__ds_scope, { TextField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TextField.jsx", error: String((e && e.message) || e) }); }

// components/forms/TimeField.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function TimeField({
  label,
  value = '',
  onChange,
  className = '',
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: 'bl-field bl-time ' + className
  }, label ? /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, label) : null, /*#__PURE__*/React.createElement("input", _extends({
    type: "time",
    className: "bl-field__input bl-time__input",
    value: value,
    onChange: e => onChange && onChange(e.target.value)
  }, rest)));
}
Object.assign(__ds_scope, { TimeField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TimeField.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Sheet.jsx
try { (() => {
function Sheet({
  open,
  onClose,
  title,
  icon,
  footer,
  children
}) {
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    className: 'bl-sheet-scrim' + (open ? ' is-open' : ''),
    onClick: onClose
  }), /*#__PURE__*/React.createElement("section", {
    role: "dialog",
    "aria-modal": "true",
    "aria-hidden": !open,
    className: 'bl-sheet' + (open ? ' is-open' : '')
  }, /*#__PURE__*/React.createElement("div", {
    className: "bl-sheet__grab"
  }), /*#__PURE__*/React.createElement("header", {
    className: "bl-sheet__head"
  }, icon, /*#__PURE__*/React.createElement("h2", {
    className: "bl-sheet__title"
  }, title), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Close",
    onClick: onClose
  })), /*#__PURE__*/React.createElement("div", {
    className: "bl-sheet__body"
  }, children), footer ? /*#__PURE__*/React.createElement("footer", {
    className: "bl-sheet__foot"
  }, footer) : null));
}
Object.assign(__ds_scope, { Sheet });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Sheet.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
function TabBar({
  items = [],
  value,
  onChange,
  className = ''
}) {
  return /*#__PURE__*/React.createElement("nav", {
    className: 'bl-tabbar ' + className
  }, items.map(it => /*#__PURE__*/React.createElement("button", {
    key: it.id,
    type: "button",
    "aria-current": it.id === value ? 'page' : undefined,
    className: 'bl-tabbar__item' + (it.id === value ? ' is-active' : ''),
    onClick: () => onChange && onChange(it.id)
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: it.icon,
    size: 24
  }), /*#__PURE__*/React.createElement("span", null, it.label), it.badge ? /*#__PURE__*/React.createElement("span", {
    className: "bl-tabbar__badge"
  }, it.badge) : null)));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Toast.jsx
try { (() => {
function Toast({
  open,
  icon = 'check',
  message,
  actionLabel,
  onAction,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    role: "status",
    className: 'bl-toast' + (open ? ' is-open' : ''),
    style: style
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 18
  }) : null, /*#__PURE__*/React.createElement("span", {
    className: "bl-toast__msg"
  }, message), actionLabel ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "bl-toast__action",
    onClick: onAction
  }, actionLabel) : null);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Toast.jsx", error: String((e && e.message) || e) }); }

// components/tracking/EventIcon.jsx
try { (() => {
// Keys match events.event_type, plus nursing (a feeding with method breast) and pump.
const EVENT_TYPES = {
  sleep: {
    label: 'Sleep',
    icon: 'moon'
  },
  feeding: {
    label: 'Bottle',
    icon: 'milk'
  },
  nursing: {
    label: 'Nursing',
    icon: 'baby'
  },
  pump: {
    label: 'Pump',
    icon: 'beaker'
  },
  diaper: {
    label: 'Diaper',
    icon: 'droplets'
  },
  meal: {
    label: 'Meal',
    icon: 'utensils'
  },
  bath: {
    label: 'Bath',
    icon: 'bath'
  },
  medicine: {
    label: 'Meds & care',
    icon: 'pill'
  },
  note: {
    label: 'Note',
    icon: 'notebook-pen'
  }
};
function EventIcon({
  type = 'note',
  size = 'md',
  className = ''
}) {
  const meta = EVENT_TYPES[type] || EVENT_TYPES.note;
  const px = size === 'sm' ? 13 : size === 'lg' ? 24 : 18;
  return /*#__PURE__*/React.createElement("span", {
    className: 'bl-evicon bl-evicon--' + size + ' bl-ev--' + type + ' ' + className
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: meta.icon,
    size: px
  }));
}
Object.assign(__ds_scope, { EVENT_TYPES, EventIcon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/EventIcon.jsx", error: String((e && e.message) || e) }); }

// components/tracking/DraftCard.jsx
try { (() => {
// Keys match match_action in the extraction schema.
const STATUS = {
  create: ['New', 'accent'],
  skip_duplicate: ['Already logged', 'neutral'],
  update_existing: ['Updates entry', 'ok']
};
function DraftCard({
  type = 'note',
  time,
  title,
  detail,
  status = 'create',
  suggestion,
  included = true,
  onToggle,
  selected,
  onSelect,
  ambiguity,
  options = [],
  onResolve
}) {
  const pair = suggestion ? ['Suggested', 'neutral'] : STATUS[status] || STATUS.create;
  return /*#__PURE__*/React.createElement("div", {
    className: 'bl-draft' + (selected ? ' is-selected' : '') + (included ? '' : ' is-skipped')
  }, /*#__PURE__*/React.createElement("div", {
    className: "bl-draft__main",
    onClick: onSelect
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    role: "checkbox",
    "aria-checked": !!included,
    "aria-label": "Include this entry",
    className: "bl-draft__check",
    onClick: e => {
      e.stopPropagation();
      if (onToggle) onToggle(!included);
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-check__box"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 16
  }))), /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
    type: type
  }), /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__text"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__time"
  }, time), /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__title"
  }, title), detail ? /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__detail"
  }, detail) : null), /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    tone: pair[1]
  }, pair[0])), ambiguity && included ? /*#__PURE__*/React.createElement("div", {
    className: "bl-draft__amb"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "triangle-alert",
    size: 16
  }), /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__ambtext"
  }, ambiguity), /*#__PURE__*/React.createElement("span", {
    className: "bl-draft__opts"
  }, options.map(o => /*#__PURE__*/React.createElement(__ds_scope.Button, {
    key: o,
    size: "sm",
    variant: "secondary",
    onClick: () => onResolve && onResolve(o)
  }, o)))) : null);
}
Object.assign(__ds_scope, { DraftCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/DraftCard.jsx", error: String((e && e.message) || e) }); }

// components/tracking/EventRow.jsx
try { (() => {
const SOURCE_ICON = {
  paper_scan: 'scan-text',
  import_huckleberry: 'download',
  control_center: 'zap'
};
function EventRow({
  type = 'note',
  time,
  title,
  detail,
  source,
  trailing,
  onClick
}) {
  const Tag = onClick ? 'button' : 'div';
  return /*#__PURE__*/React.createElement(Tag, {
    type: onClick ? 'button' : undefined,
    className: "bl-event",
    onClick: onClick
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-event__time"
  }, time), /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
    type: type
  }), /*#__PURE__*/React.createElement("span", {
    className: "bl-event__main"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-event__title"
  }, title), detail ? /*#__PURE__*/React.createElement("span", {
    className: "bl-event__detail"
  }, detail) : null), /*#__PURE__*/React.createElement("span", {
    className: "bl-event__trail"
  }, trailing, SOURCE_ICON[source] ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: SOURCE_ICON[source],
    size: 16
  }) : null));
}
Object.assign(__ds_scope, { EventRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/EventRow.jsx", error: String((e && e.message) || e) }); }

// components/tracking/GlanceStat.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function GlanceStat({
  type,
  label,
  value,
  sub,
  className = '',
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: 'bl-glance ' + className
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "bl-glance__label bl-label"
  }, type ? /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
    type: type,
    size: "sm"
  }) : null, label), /*#__PURE__*/React.createElement("span", {
    className: "bl-glance__value"
  }, value), sub ? /*#__PURE__*/React.createElement("span", {
    className: "bl-glance__sub"
  }, sub) : null);
}
Object.assign(__ds_scope, { GlanceStat });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/GlanceStat.jsx", error: String((e && e.message) || e) }); }

// components/tracking/NapCard.jsx
try { (() => {
function NapCard({
  state = 'awake',
  label,
  elapsed = '',
  progress = 0,
  over,
  caption,
  actionLabel,
  onAction,
  secondaryLabel,
  onSecondary
}) {
  const asleep = state === 'asleep';
  const parts = String(elapsed).split(/(\d+)/).filter(p => p.trim() !== '');
  const pct = Math.min(1, Math.max(0, progress)) * 100;
  return /*#__PURE__*/React.createElement("section", {
    className: 'bl-nap bl-nap--' + state + ' bl-ev--sleep'
  }, /*#__PURE__*/React.createElement("div", {
    className: "bl-nap__top"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, label), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: asleep ? 'moon' : 'sun',
    size: 18
  })), /*#__PURE__*/React.createElement("div", {
    className: "bl-nap__timer"
  }, parts.map((p, i) => /\d/.test(p) ? /*#__PURE__*/React.createElement("span", {
    key: i
  }, p) : /*#__PURE__*/React.createElement("span", {
    key: i,
    className: "bl-nap__unit"
  }, p.trim()))), /*#__PURE__*/React.createElement("div", {
    className: "bl-nap__rail"
  }, /*#__PURE__*/React.createElement("div", {
    className: 'bl-nap__fill' + (over ? ' is-over' : ''),
    style: {
      width: pct + '%'
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "bl-nap__tick"
  })), caption ? /*#__PURE__*/React.createElement("div", {
    className: "bl-nap__caption"
  }, caption) : null, actionLabel ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: asleep ? 'ink' : 'primary',
    size: "lg",
    block: true,
    icon: asleep ? 'sun' : 'moon',
    onClick: onAction
  }, actionLabel) : null, secondaryLabel ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "ghost",
    block: true,
    className: "bl-nap__secondary",
    onClick: onSecondary
  }, secondaryLabel) : null);
}
Object.assign(__ds_scope, { NapCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/NapCard.jsx", error: String((e && e.message) || e) }); }

// components/tracking/NursingTimer.jsx
try { (() => {
function fmt(sec) {
  const s = Math.max(0, Math.floor(sec || 0));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}
function NursingTimer({
  left = 0,
  right = 0,
  active = null,
  onSide
}) {
  const side = (id, label, sec) => {
    const on = active === id;
    return /*#__PURE__*/React.createElement("button", {
      type: "button",
      "aria-pressed": on,
      className: 'bl-nurse__side' + (on ? ' is-active' : ''),
      onClick: () => onSide && onSide(id)
    }, /*#__PURE__*/React.createElement("span", {
      className: "bl-label"
    }, label), /*#__PURE__*/React.createElement("span", {
      className: "bl-nurse__time"
    }, fmt(sec)), /*#__PURE__*/React.createElement("span", {
      className: "bl-nurse__state"
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: on ? 'pause' : 'play',
      size: 16
    }), on ? 'Pause' : active ? 'Switch' : sec > 0 ? 'Resume' : 'Start'));
  };
  return /*#__PURE__*/React.createElement("div", {
    className: "bl-nurse"
  }, /*#__PURE__*/React.createElement("div", {
    className: "bl-nurse__total"
  }, fmt(left + right)), /*#__PURE__*/React.createElement("div", {
    className: "bl-nurse__sides"
  }, side('left', 'Left', left), side('right', 'Right', right)));
}
Object.assign(__ds_scope, { NursingTimer });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/NursingTimer.jsx", error: String((e && e.message) || e) }); }

// components/tracking/QuickTile.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function QuickTile({
  type = 'note',
  label,
  sub,
  size = 'md',
  className = '',
  ...rest
}) {
  const meta = __ds_scope.EVENT_TYPES[type] || __ds_scope.EVENT_TYPES.note;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: 'bl-tile bl-tile--' + size + ' bl-ev--' + type + ' ' + className
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
    type: type,
    size: size === 'lg' ? 'lg' : 'md'
  }), /*#__PURE__*/React.createElement("span", {
    className: "bl-tile__text"
  }, /*#__PURE__*/React.createElement("span", null, label || meta.label), sub ? /*#__PURE__*/React.createElement("span", {
    className: "bl-tile__sub"
  }, sub) : null));
}
Object.assign(__ds_scope, { QuickTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/tracking/QuickTile.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/KitData.jsx
try { (() => {
// Sample data for the click-through. Times are minutes since midnight on Wed, Nov 25.
const BASE_NOW = 774; // 12:54 PM
const SCHEDULE = {
  windows: [150, 195],
  napCap: 90,
  bedtime: 240
};
function clock(min) {
  const m = (Math.round(min) % 1440 + 1440) % 1440;
  const h = Math.floor(m / 60);
  return (h + 11) % 12 + 1 + ':' + String(m % 60).padStart(2, '0') + ' ' + (h < 12 ? 'AM' : 'PM');
}
function dur(min) {
  const m = Math.max(0, Math.round(min));
  const h = Math.floor(m / 60);
  return h ? h + 'h ' + m % 60 + 'm' : m + 'm';
}
function range(a, b) {
  const x = clock(a),
    y = clock(b);
  return (x.slice(-2) === y.slice(-2) ? x.slice(0, -3) : x) + ' – ' + y;
}
function toHM(min) {
  const m = (Math.round(min) % 1440 + 1440) % 1440;
  return String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
}
function fromHM(s) {
  const p = String(s).split(':');
  return +p[0] * 60 + +p[1];
}
// Live seconds per side for a running nursing session { left, right, active, since }.
function nurseSecs(n) {
  if (!n) return {
    left: 0,
    right: 0,
    total: 0
  };
  const live = n.active ? (Date.now() - n.since) / 1000 : 0;
  const left = n.left + (n.active === 'left' ? live : 0),
    right = n.right + (n.active === 'right' ? live : 0);
  return {
    left: left,
    right: right,
    total: left + right
  };
}
function mmss(sec) {
  const s = Math.max(0, Math.floor(sec));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

// `form` holds the log-sheet field values so an entry can be reopened for editing.
const INITIAL_EVENTS = [{
  id: 'a1',
  type: 'sleep',
  nap: false,
  t: 405,
  start: -290,
  end: 405,
  title: 'Night sleep',
  detail: '7:10 PM – 6:45 AM · 11h 35m',
  source: 'manual'
}, {
  id: 'a2',
  type: 'feeding',
  t: 420,
  oz: 4,
  title: 'Bottle',
  detail: '4 oz formula',
  source: 'manual',
  form: {
    amount: '4',
    unit: 'oz',
    substance: 'Formula'
  }
}, {
  id: 'a3',
  type: 'diaper',
  t: 425,
  title: 'Diaper',
  detail: 'Pee M',
  source: 'manual',
  form: {
    pee: 'M',
    poop: 'None'
  }
}, {
  id: 'a4',
  type: 'meal',
  t: 480,
  title: 'Breakfast',
  detail: 'Oatmeal, banana · Some eaten',
  source: 'manual',
  form: {
    slot: 'Breakfast',
    ate: 'Oatmeal, banana',
    portion: 'Some'
  }
}, {
  id: 'a5',
  type: 'sleep',
  nap: true,
  t: 555,
  start: 555,
  end: 632,
  title: 'Nap 1',
  detail: '9:15 – 10:32 AM · 1h 17m',
  source: 'paper_scan'
}, {
  id: 'a5p',
  type: 'pump',
  t: 585,
  title: 'Pump',
  detail: '4.5 oz · Both sides',
  source: 'manual',
  form: {
    amount: '4.5',
    unit: 'oz',
    pumpSide: 'Both'
  }
}, {
  id: 'a6',
  type: 'diaper',
  t: 640,
  title: 'Diaper',
  detail: 'Pee L · Poop S',
  source: 'paper_scan',
  form: {
    pee: 'L',
    poop: 'S'
  }
}, {
  id: 'a7',
  type: 'feeding',
  t: 645,
  oz: 2.5,
  breast: true,
  title: 'Bottle',
  detail: '2.5 oz breast milk',
  source: 'paper_scan',
  form: {
    amount: '2.5',
    unit: 'oz',
    substance: 'Breast milk'
  }
}];

// Extraction result for the 12:50 PM photo. `row` ties a draft to its line on the sheet; `ev` is merged into the saved event.
const DRAFTS = [{
  id: 's1',
  row: 'nap',
  type: 'sleep',
  t: 555,
  time: '9:15 AM',
  title: 'Nap 1',
  detail: 'Until 10:32 AM · 1h 17m',
  status: 'skip_duplicate',
  ev: {
    nap: true,
    start: 555,
    end: 632,
    detail: '9:15 – 10:32 AM · 1h 17m'
  }
}, {
  id: 's2',
  row: 'd1',
  type: 'diaper',
  t: 640,
  time: '10:40 AM',
  title: 'Diaper',
  detail: 'Pee L · Poop S',
  status: 'skip_duplicate',
  ev: {
    form: {
      pee: 'L',
      poop: 'S'
    }
  }
}, {
  id: 's3',
  row: 'b1',
  type: 'feeding',
  t: 645,
  time: '10:45 AM',
  title: 'Bottle',
  detail: '2.5 oz breast milk',
  status: 'skip_duplicate',
  ev: {
    oz: 2.5,
    breast: true,
    form: {
      amount: '2.5',
      unit: 'oz',
      substance: 'Breast milk'
    }
  }
}, {
  id: 's4',
  row: 'b1',
  type: 'medicine',
  t: 645,
  time: '10:45 AM',
  title: 'Vitamin D',
  detail: 'The row is labelled + VIT D',
  saved: '1 drop · supplement',
  status: 'create',
  suggestion: true,
  ev: {
    form: {
      med: 'Vitamin D',
      dose: '1',
      doseUnit: 'drops'
    }
  }
}, {
  id: 's5',
  row: 'd2',
  type: 'diaper',
  t: 680,
  time: '11:20 AM',
  title: 'Diaper',
  detail: 'Pee L',
  status: 'create',
  ambiguity: 'The time was written over. Which is it?',
  options: ['11:20 AM', '11:30 AM'],
  ev: {
    form: {
      pee: 'L',
      poop: 'None'
    }
  }
}, {
  id: 's6',
  row: 'lunch',
  type: 'meal',
  t: 720,
  time: '12:00 PM',
  title: 'Lunch',
  detail: 'Most eaten',
  status: 'create',
  ev: {
    form: {
      slot: 'Lunch',
      portion: 'Most'
    }
  }
}, {
  id: 's7',
  row: 'd3',
  type: 'diaper',
  t: 740,
  time: '12:20 PM',
  title: 'Diaper',
  detail: 'Pee M',
  status: 'create',
  ev: {
    form: {
      pee: 'M',
      poop: 'None'
    }
  }
}];
Object.assign(__ds_scope, { BASE_NOW, SCHEDULE, clock, dur, range, toHM, fromHM, nurseSecs, mmss, INITIAL_EVENTS, DRAFTS });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/KitData.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/LogSheet.jsx
try { (() => {
const TITLES = {
  sleep: 'Sleep',
  feeding: 'Bottle',
  nursing: 'Nursing',
  pump: 'Pump',
  diaper: 'Diaper',
  meal: 'Meal',
  bath: 'Bath',
  medicine: 'Meds & care',
  note: 'Note'
};
const PRESETS = {
  oz: ['2', '2.5', '3', '3.25', '4', '5'],
  mL: ['60', '75', '90', '100', '120', '150']
};
const PUMP_PRESETS = {
  oz: ['2', '3', '4', '5', '6', '8'],
  mL: ['60', '90', '120', '150', '180', '240']
};
const NURSE_PRESETS = ['5', '10', '15', '20', '25', '30'];
// name -> [dose, unit, category]; null dose = topical, no dose asked.
const MEDS = {
  'Vitamin D': ['1', 'drops', 'supplement'],
  'Infant Tylenol': ['2.5', 'mL', 'medicine'],
  'Butt cream': [null, null, 'topical'],
  'Saline drops': ['2', 'drops', 'medicine'],
  'Gas drops': ['0.3', 'mL', 'medicine'],
  'Custom': ['', 'mL', 'medicine']
};
const AGO = [[0, 'Now'], [5, '5m ago'], [15, '15m ago']];
const DEFAULTS = {
  ago: 0,
  at: null,
  amount: '3.25',
  unit: 'oz',
  substance: 'Formula',
  vitd: false,
  nurseMode: 'Timer',
  minutes: '10',
  side: 'Left',
  pumpSide: 'Both',
  kind: 'Nap',
  start: 0,
  end: 0,
  pee: 'M',
  poop: 'None',
  rash: false,
  slot: 'Lunch',
  ate: '',
  portion: 'Most',
  hair: 'No',
  bathNote: '',
  med: 'Vitamin D',
  dose: '1',
  doseUnit: 'drops',
  note: ''
};
function slotFor(now) {
  return now < 630 ? 'Breakfast' : now < 900 ? 'Lunch' : now < 1020 ? 'Snack' : 'Dinner';
}
function convert(amount, unit) {
  const n = parseFloat(amount);
  if (!n) return '';
  return unit === 'mL' ? String(Math.round(n * 29.57 / 5) * 5) : String(Math.round(n / 29.57 * 4) / 4);
}
function sides(s) {
  return s === 'Both' ? 'Both sides' : s + ' side';
}
function unitText(dose, u) {
  return u === 'drops' && parseFloat(dose) === 1 ? 'drop' : u;
}
function Field({
  label,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-field"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, label), children);
}
function LogSheet({
  type = 'feeding',
  open,
  now,
  unit = 'oz',
  nap,
  napsDone = 0,
  edit,
  nurse,
  onClose,
  onSave,
  onUpdate,
  onDelete,
  onNapStart,
  onNurseSide,
  onNurseFinish,
  onNurseDiscard
}) {
  const [f, setF] = React.useState(DEFAULTS);
  const set = patch => setF(s => Object.assign({}, s, patch));
  React.useEffect(() => {
    if (!open) return;
    const n = Math.round(now),
      ml = unit === 'mL';
    const base = Object.assign({}, DEFAULTS, {
      unit: unit,
      amount: type === 'pump' ? ml ? '120' : '4' : ml ? '95' : '3.25',
      slot: slotFor(now),
      start: nap ? Math.round(nap.since) : n - 60,
      end: n
    });
    if (edit) {
      Object.assign(base, edit.form, {
        ago: 0,
        at: Math.round(edit.t),
        nurseMode: 'Enter minutes'
      });
      if (edit.type === 'sleep') Object.assign(base, {
        kind: edit.nap ? 'Nap' : 'Night sleep',
        start: Math.round(edit.start),
        end: Math.round(edit.end)
      });
    }
    setF(base);
  }, [open, type, edit && edit.id]);
  const t = f.at != null ? f.at : now - f.ago;
  const topical = MEDS[f.med][0] === null;
  const setUnit = u => set({
    unit: u,
    amount: u === f.unit ? f.amount : convert(f.amount, u)
  });
  const amountRow = /*#__PURE__*/React.createElement("div", {
    className: "kit-amount"
  }, /*#__PURE__*/React.createElement(__ds_scope.AmountField, {
    value: f.amount,
    onChange: v => set({
      amount: v
    }),
    unit: f.unit
  }), /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
    size: "sm",
    options: ['oz', 'mL'],
    value: f.unit,
    onChange: setUnit
  }));
  const presetRow = list => /*#__PURE__*/React.createElement("div", {
    className: "kit-chips kit-chips--even",
    style: {
      gridTemplateColumns: 'repeat(6, 1fr)'
    }
  }, list.map(p => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: p,
    selected: f.amount === p,
    onClick: () => set({
      amount: p
    })
  }, p)));
  const modeSwitch = /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
    block: true,
    options: ['Timer', 'Enter minutes'],
    value: f.nurseMode,
    onChange: v => set({
      nurseMode: v
    })
  });
  let body,
    cta,
    events,
    message,
    ok = true,
    timeLabel = 'Time',
    save = null,
    aside = null;
  if (type === 'sleep' && nap && !edit) {
    timeLabel = null;
    cta = 'Set start to ' + __ds_scope.clock(f.start);
    save = () => onNapStart(f.start);
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(__ds_scope.TimeField, {
      label: "Fell asleep",
      value: __ds_scope.toHM(f.start),
      onChange: v => v && set({
        start: __ds_scope.fromHM(v)
      })
    }), /*#__PURE__*/React.createElement("p", {
      className: "kit-hint"
    }, "The timer keeps running on every device."));
  } else if (type === 'sleep') {
    timeLabel = null;
    const night = f.kind === 'Night sleep';
    const s = night && f.start >= f.end ? f.start - 1440 : f.start;
    const len = f.end - s;
    ok = len > 0;
    cta = ok ? 'Log ' + __ds_scope.dur(len) + (night ? ' night sleep' : ' nap') : 'End is before start';
    events = [{
      type: 'sleep',
      nap: !night,
      t: night ? f.end : s,
      start: s,
      end: f.end,
      title: night ? 'Night sleep' : edit && edit.nap ? edit.title : 'Nap ' + (napsDone + 1),
      detail: __ds_scope.range(s, f.end) + ' · ' + __ds_scope.dur(len)
    }];
    message = (night ? 'Night sleep' : 'Nap') + ' logged · ' + __ds_scope.dur(len);
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['Nap', 'Night sleep'],
      value: f.kind,
      onChange: v => set({
        kind: v
      })
    }), /*#__PURE__*/React.createElement("div", {
      className: "kit-pair"
    }, /*#__PURE__*/React.createElement(__ds_scope.TimeField, {
      label: "Start",
      value: __ds_scope.toHM(f.start),
      onChange: v => v && set({
        start: __ds_scope.fromHM(v)
      })
    }), /*#__PURE__*/React.createElement(__ds_scope.TimeField, {
      label: "End",
      value: __ds_scope.toHM(f.end),
      onChange: v => v && set({
        end: __ds_scope.fromHM(v)
      })
    })), /*#__PURE__*/React.createElement("p", {
      className: "kit-hint"
    }, ok ? __ds_scope.dur(len) + ' asleep' + (s < 0 ? ' · started yesterday' : '') : 'Pick an end time after the start.'));
  } else if (type === 'feeding') {
    cta = 'Log ' + (f.amount || '0') + ' ' + f.unit;
    const detail = f.amount + ' ' + f.unit + ' ' + f.substance.toLowerCase();
    events = [{
      type: 'feeding',
      t: t,
      oz: f.unit === 'oz' ? parseFloat(f.amount) || 0 : (parseFloat(f.amount) || 0) / 29.57,
      breast: f.substance === 'Breast milk',
      title: 'Bottle',
      detail: detail
    }];
    if (f.vitd && !edit) events.push({
      type: 'medicine',
      t: t,
      title: 'Vitamin D',
      detail: '1 drop · supplement'
    });
    message = 'Bottle logged · ' + f.amount + ' ' + f.unit;
    body = /*#__PURE__*/React.createElement(React.Fragment, null, amountRow, presetRow(PRESETS[f.unit]), /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['Formula', 'Breast milk', 'Mixed'],
      value: f.substance,
      onChange: v => set({
        substance: v
      })
    }), edit ? null : /*#__PURE__*/React.createElement(__ds_scope.Checkbox, {
      checked: f.vitd,
      onChange: v => set({
        vitd: v
      }),
      label: "+ Vitamin D",
      sub: "Logs a supplement alongside this bottle"
    }));
  } else if (type === 'nursing' && !edit && (nurse || f.nurseMode === 'Timer')) {
    timeLabel = null;
    const s = __ds_scope.nurseSecs(nurse);
    ok = !!nurse;
    cta = nurse ? 'Log ' + Math.max(1, Math.round(s.total / 60)) + ' min nursing' : 'Tap a side to start';
    save = onNurseFinish;
    aside = nurse ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
      variant: "danger",
      size: "lg",
      icon: "trash-2",
      "aria-label": "Discard timer",
      onClick: onNurseDiscard
    }) : null;
    body = /*#__PURE__*/React.createElement(React.Fragment, null, nurse ? /*#__PURE__*/React.createElement("div", {
      className: "kit-nursehead"
    }, /*#__PURE__*/React.createElement("span", {
      className: "bl-label"
    }, "Started ", __ds_scope.clock(nurse.startedAt)), /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      event: "nursing"
    }, nurse.active ? 'Running' : 'Paused')) : modeSwitch, /*#__PURE__*/React.createElement(__ds_scope.NursingTimer, {
      left: s.left,
      right: s.right,
      active: nurse ? nurse.active : null,
      onSide: onNurseSide
    }), /*#__PURE__*/React.createElement("p", {
      className: "kit-hint"
    }, nurse ? 'Runs on every device. You can close this.' : 'Tap a side to start the timer.'));
  } else if (type === 'nursing') {
    timeLabel = 'Started';
    const mins = f.minutes || '0';
    cta = 'Log ' + mins + ' min nursing';
    events = [{
      type: 'feeding',
      kind: 'nursing',
      t: t,
      min: parseFloat(mins) || 0,
      title: 'Nursing',
      detail: mins + 'm · ' + sides(f.side)
    }];
    message = 'Nursing logged · ' + mins + 'm';
    body = /*#__PURE__*/React.createElement(React.Fragment, null, edit ? null : modeSwitch, /*#__PURE__*/React.createElement(__ds_scope.AmountField, {
      value: f.minutes,
      onChange: v => set({
        minutes: v
      }),
      unit: "min"
    }), /*#__PURE__*/React.createElement("div", {
      className: "kit-chips kit-chips--even",
      style: {
        gridTemplateColumns: 'repeat(6, 1fr)'
      }
    }, NURSE_PRESETS.map(p => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
      key: p,
      selected: f.minutes === p,
      onClick: () => set({
        minutes: p
      })
    }, p))), /*#__PURE__*/React.createElement(Field, {
      label: "Side"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['Left', 'Right', 'Both'],
      value: f.side,
      onChange: v => set({
        side: v
      })
    })));
  } else if (type === 'pump') {
    cta = 'Log ' + (f.amount || '0') + ' ' + f.unit + ' pumped';
    events = [{
      type: 'pump',
      t: t,
      title: 'Pump',
      detail: f.amount + ' ' + f.unit + ' · ' + sides(f.pumpSide)
    }];
    message = 'Pump logged · ' + f.amount + ' ' + f.unit;
    body = /*#__PURE__*/React.createElement(React.Fragment, null, amountRow, presetRow(PUMP_PRESETS[f.unit]), /*#__PURE__*/React.createElement(Field, {
      label: "Side"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['Left', 'Right', 'Both'],
      value: f.pumpSide,
      onChange: v => set({
        pumpSide: v
      })
    })));
  } else if (type === 'diaper') {
    cta = 'Log diaper';
    const parts = [f.pee !== 'None' && 'Pee ' + f.pee, f.poop !== 'None' && 'Poop ' + f.poop, f.rash && 'Rash'].filter(Boolean);
    events = [{
      type: 'diaper',
      t: t,
      title: 'Diaper',
      detail: parts.join(' · ') || 'Dry'
    }];
    message = 'Diaper logged · ' + (parts.join(' · ') || 'Dry');
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Field, {
      label: "Pee"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['None', 'S', 'M', 'L'],
      value: f.pee,
      onChange: v => set({
        pee: v
      })
    })), /*#__PURE__*/React.createElement(Field, {
      label: "Poop"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['None', 'S', 'M', 'L'],
      value: f.poop,
      onChange: v => set({
        poop: v
      })
    })), /*#__PURE__*/React.createElement(__ds_scope.Checkbox, {
      checked: f.rash,
      onChange: v => set({
        rash: v
      }),
      label: "Rash"
    }));
  } else if (type === 'meal') {
    cta = 'Log ' + f.slot.toLowerCase();
    events = [{
      type: 'meal',
      t: t,
      title: f.slot,
      detail: [f.ate, f.portion + ' eaten'].filter(Boolean).join(' · ')
    }];
    message = f.slot + ' logged';
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      options: ['Breakfast', 'Lunch', 'Dinner', 'Snack'],
      value: f.slot,
      onChange: v => set({
        slot: v
      })
    }), /*#__PURE__*/React.createElement(__ds_scope.TextField, {
      label: "What she ate",
      placeholder: "Optional",
      value: f.ate,
      onChange: v => set({
        ate: v
      })
    }), /*#__PURE__*/React.createElement(Field, {
      label: "How much"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['None', 'Some', 'Most'],
      value: f.portion,
      onChange: v => set({
        portion: v
      })
    })));
  } else if (type === 'bath') {
    cta = 'Log bath';
    events = [{
      type: 'bath',
      t: t,
      title: 'Bath',
      detail: [f.hair === 'Yes' ? 'Hair shampooed' : 'No shampoo', f.bathNote].filter(Boolean).join(' · ')
    }];
    message = 'Bath logged';
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Field, {
      label: "Shampooed hair?"
    }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      block: true,
      size: "lg",
      options: ['No', 'Yes'],
      value: f.hair,
      onChange: v => set({
        hair: v
      })
    })), /*#__PURE__*/React.createElement(__ds_scope.TextField, {
      label: "Notes",
      placeholder: "Optional",
      value: f.bathNote,
      onChange: v => set({
        bathNote: v
      })
    }));
  } else if (type === 'medicine') {
    cta = 'Log ' + (f.med === 'Custom' ? 'care' : f.med);
    events = [{
      type: 'medicine',
      t: t,
      title: f.med,
      detail: topical ? 'Topical' : f.dose + ' ' + unitText(f.dose, f.doseUnit) + ' · ' + MEDS[f.med][2]
    }];
    message = f.med + ' logged';
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
      className: "kit-chips"
    }, Object.keys(MEDS).map(m => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
      key: m,
      selected: f.med === m,
      onClick: () => set({
        med: m,
        dose: MEDS[m][0] || '',
        doseUnit: MEDS[m][1] || 'mL'
      })
    }, m))), topical ? /*#__PURE__*/React.createElement("p", {
      className: "kit-hint"
    }, "Topical care. No dose needed.") : /*#__PURE__*/React.createElement("div", {
      className: "kit-amount"
    }, /*#__PURE__*/React.createElement(__ds_scope.AmountField, {
      size: "md",
      value: f.dose,
      onChange: v => set({
        dose: v
      }),
      unit: f.doseUnit
    }), /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      size: "sm",
      options: ['mL', 'drops', 'mg'],
      value: f.doseUnit,
      onChange: v => set({
        doseUnit: v
      })
    })));
  } else {
    cta = 'Save note';
    events = [{
      type: 'note',
      t: t,
      title: 'Note',
      detail: f.note || 'No text'
    }];
    message = 'Note saved';
    body = /*#__PURE__*/React.createElement(__ds_scope.TextField, {
      multiline: true,
      rows: 4,
      placeholder: "Anything worth remembering about today",
      value: f.note,
      onChange: v => set({
        note: v
      })
    });
  }
  if (edit && events) {
    if (ok) cta = 'Save changes';
    save = () => onUpdate(edit.id, Object.assign({
      form: f
    }, events[0]), events[0].title + ' updated');
    aside = /*#__PURE__*/React.createElement(__ds_scope.Button, {
      variant: "danger",
      size: "lg",
      icon: "trash-2",
      "aria-label": "Delete entry",
      onClick: () => onDelete(edit)
    });
  }
  const commit = save || (() => onSave(events.map(e => Object.assign({
    form: f
  }, e)), message));
  return /*#__PURE__*/React.createElement(__ds_scope.Sheet, {
    open: open,
    onClose: onClose,
    title: TITLES[type],
    icon: /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
      type: type
    }),
    footer: /*#__PURE__*/React.createElement("div", {
      className: "kit-foot"
    }, aside, /*#__PURE__*/React.createElement(__ds_scope.Button, {
      size: "lg",
      block: true,
      disabled: !ok,
      onClick: commit
    }, cta))
  }, body, timeLabel ? /*#__PURE__*/React.createElement("div", {
    className: "kit-field"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, timeLabel), edit ? /*#__PURE__*/React.createElement(__ds_scope.TimeField, {
    "aria-label": timeLabel,
    value: __ds_scope.toHM(t),
    onChange: v => v && set({
      at: __ds_scope.fromHM(v)
    })
  }) : /*#__PURE__*/React.createElement("div", {
    className: "kit-time"
  }, /*#__PURE__*/React.createElement(__ds_scope.TimeField, {
    "aria-label": timeLabel,
    value: __ds_scope.toHM(t),
    onChange: v => v && set({
      at: __ds_scope.fromHM(v)
    })
  }), AGO.map(a => /*#__PURE__*/React.createElement(__ds_scope.Chip, {
    key: a[0],
    selected: f.at == null && f.ago === a[0],
    onClick: () => set({
      ago: a[0],
      at: null
    })
  }, a[1])))) : null);
}
Object.assign(__ds_scope, { LogSheet });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/LogSheet.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/PhoneFrame.jsx
try { (() => {
function PhoneFrame({
  theme = 'day',
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-phone"
  }, /*#__PURE__*/React.createElement("div", {
    className: "kit-phone__screen",
    "data-theme": theme === 'night' ? 'night' : undefined
  }, /*#__PURE__*/React.createElement("div", {
    className: "kit-status"
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", {
    className: "kit-status__island"
  }), /*#__PURE__*/React.createElement("span", {
    className: "kit-status__sys"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "signal",
    size: 16
  }), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "wifi",
    size: 16
  }), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "battery-full",
    size: 22
  }))), /*#__PURE__*/React.createElement("div", {
    className: "kit-body"
  }, children)));
}
Object.assign(__ds_scope, { PhoneFrame });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/PhoneFrame.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/RhythmScreen.jsx
try { (() => {
const DAYS = [['Thu', 19], ['Fri', 20], ['Sat', 21], ['Sun', 22], ['Mon', 23], ['Tue', 24], ['Wed', 25]];
const HOURS = [[0, '12a'], [3, '3a'], [6, '6a'], [9, '9a'], [12, '12p'], [15, '3p'], [18, '6p'], [21, '9p']];
const PX = 16 / 60; // 16px per hour

function rnd(i) {
  const x = Math.sin(i * 99.13) * 43758.5453;
  return x - Math.floor(x);
}
function pastDay(d) {
  const j = k => Math.round((rnd(d * 11 + k) - 0.5) * 36);
  const wake = 405 + j(1),
    n1 = 555 + j(2),
    n1e = n1 + 72 + j(3) / 2,
    n2 = 835 + j(4),
    n2e = n2 + 78 + j(5) / 2,
    bed = 1150 + j(6);
  return {
    sleep: [[0, wake], [n1, n1e], [n2, n2e], [bed, 1440]],
    feeds: [[wake + 15, 4, false], [n1e + 13, 2.5, true], [n2e + 10, 4, false], [bed - 30, 5, false]],
    meals: [480 + j(7), 720 + j(8) / 3, 1050 + j(9)],
    diapers: [wake + 20, n1e + 8, 740 + j(10), n2e + 5, 1085 + j(11)],
    nursing: []
  };
}
function today(events, nap, now) {
  const sleep = events.filter(e => e.type === 'sleep').map(e => [Math.max(0, e.start), e.end]);
  if (nap) sleep.push([nap.since, now]);
  return {
    sleep: sleep,
    feeds: events.filter(e => e.type === 'feeding' && e.kind !== 'nursing').map(e => [e.t, e.oz || 0, !!e.breast]),
    nursing: events.filter(e => e.kind === 'nursing').map(e => [e.t, e.min || 0]),
    meals: events.filter(e => e.type === 'meal').map(e => e.t),
    diapers: events.filter(e => e.type === 'diaper').map(e => e.t)
  };
}
function RhythmScreen({
  now,
  events,
  nap
}) {
  const [sel, setSel] = React.useState(6);
  const days = DAYS.map((_, i) => i === 6 ? today(events, nap, now) : pastDay(i + 1));
  const d = days[sel];
  const sleepMin = d.sleep.reduce((s, x) => s + (x[1] - x[0]), 0);
  const oz = Math.round(d.feeds.reduce((s, x) => s + x[1], 0) * 100) / 100;
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-view"
  }, /*#__PURE__*/React.createElement("header", {
    className: "kit-head"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    className: "bl-label"
  }, "Nov 19 \u2013 25"), /*#__PURE__*/React.createElement("h1", {
    className: "kit-title"
  }, "Rhythm"))), /*#__PURE__*/React.createElement("div", {
    className: "kit-scroll"
  }, /*#__PURE__*/React.createElement("div", {
    className: "rh-legend"
  }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--sleep"
  }), "Sleep"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--formula"
  }), "Formula"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--breast"
  }), "Breast milk"), days.some(x => x.nursing.length) ? /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--nurse"
  }), "Nursing") : null, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--meal"
  }), "Meal"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    className: "rh-key rh-key--diaper"
  }), "Diaper")), /*#__PURE__*/React.createElement("div", {
    className: "rh-chart"
  }, /*#__PURE__*/React.createElement("span", null), DAYS.map((day, i) => /*#__PURE__*/React.createElement("button", {
    key: i,
    type: "button",
    className: 'rh-day' + (sel === i ? ' is-selected' : ''),
    onClick: () => setSel(i)
  }, /*#__PURE__*/React.createElement("span", null, day[0][0]), /*#__PURE__*/React.createElement("b", null, day[1]))), /*#__PURE__*/React.createElement("div", {
    className: "rh-hours"
  }, HOURS.map(h => /*#__PURE__*/React.createElement("span", {
    key: h[0],
    style: {
      top: h[0] * 16
    }
  }, h[1]))), days.map((day, i) => /*#__PURE__*/React.createElement("button", {
    key: i,
    type: "button",
    "aria-label": DAYS[i][0],
    className: 'rh-col' + (sel === i ? ' is-selected' : ''),
    onClick: () => setSel(i)
  }, day.sleep.map((s, k) => /*#__PURE__*/React.createElement("span", {
    key: 's' + k,
    className: "rh-sleep",
    style: {
      top: s[0] * PX,
      height: Math.max(2, (s[1] - s[0]) * PX)
    }
  })), day.feeds.map((x, k) => /*#__PURE__*/React.createElement("span", {
    key: 'f' + k,
    className: 'rh-feed' + (x[2] ? ' is-breast' : ''),
    style: {
      top: x[0] * PX
    }
  })), day.nursing.map((x, k) => /*#__PURE__*/React.createElement("span", {
    key: 'n' + k,
    className: "rh-nurse",
    style: {
      top: x[0] * PX,
      height: Math.max(5, x[1] * PX)
    }
  })), day.meals.map((m, k) => /*#__PURE__*/React.createElement("span", {
    key: 'm' + k,
    className: "rh-meal",
    style: {
      top: m * PX
    }
  })), day.diapers.map((m, k) => /*#__PURE__*/React.createElement("span", {
    key: 'd' + k,
    className: "rh-diaper",
    style: {
      top: m * PX
    }
  })), i === 6 ? /*#__PURE__*/React.createElement("span", {
    className: "rh-now",
    style: {
      top: now * PX
    }
  }) : null))), /*#__PURE__*/React.createElement(__ds_scope.Card, {
    className: "rh-card"
  }, /*#__PURE__*/React.createElement("div", {
    className: "rh-card__head"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, DAYS[sel][0], ", Nov ", DAYS[sel][1]), sel === 6 ? /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, "So far") : null), /*#__PURE__*/React.createElement("div", {
    className: "rh-totals"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("b", null, __ds_scope.dur(sleepMin)), /*#__PURE__*/React.createElement("span", null, "Sleep")), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("b", null, oz, " oz"), /*#__PURE__*/React.createElement("span", null, d.feeds.length, " bottles", d.nursing.length ? ' · ' + d.nursing.length + ' nursing' : '')), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("b", null, d.diapers.length), /*#__PURE__*/React.createElement("span", null, "Diapers")), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("b", null, d.meals.length), /*#__PURE__*/React.createElement("span", null, "Meals"))))));
}
Object.assign(__ds_scope, { RhythmScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/RhythmScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/ScanScreens.jsx
try { (() => {
// Stand-in for the scanned photo. The real app shows the camera image here.
const ROWS = [{
  k: 'nap',
  label: 'NAP 1',
  target: '9:15–10:45',
  hand: '9:15 – 10:32'
}, {
  k: 'd1',
  label: 'DIAPER',
  hand: '10:40  pee L  poop S'
}, {
  k: 'b1',
  label: 'BOTTLE',
  pills: ['BREAST MILK', '+ VIT D'],
  target: '2–4 oz',
  hand: '2½ oz  10:45'
}, {
  k: 'd2',
  label: 'DIAPER',
  hand: /*#__PURE__*/React.createElement("span", null, "11:", /*#__PURE__*/React.createElement("span", {
    className: "rv-over"
  }, "2", /*#__PURE__*/React.createElement("i", null, "3")), "0  pee L")
}, {
  k: 'lunch',
  label: 'LUNCH',
  target: '12:00',
  hand: '12:00  most'
}, {
  k: 'd3',
  label: 'DIAPER',
  hand: '12:20  pee M'
}];
function SheetsScreen({
  pending,
  onScan,
  onReview
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-view"
  }, /*#__PURE__*/React.createElement("header", {
    className: "kit-head"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    className: "bl-label"
  }, "Grandma's paper logs"), /*#__PURE__*/React.createElement("h1", {
    className: "kit-title"
  }, "Sheets"))), /*#__PURE__*/React.createElement("div", {
    className: "kit-scroll"
  }, /*#__PURE__*/React.createElement(__ds_scope.Card, null, /*#__PURE__*/React.createElement("p", {
    className: "kit-lede"
  }, "Photograph today's sheet. Nothing is saved until you confirm each entry."), /*#__PURE__*/React.createElement("div", {
    className: "kit-stack"
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "lg",
    block: true,
    icon: "scan-text",
    onClick: onScan
  }, "Scan today's sheet"), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "secondary",
    block: true,
    icon: "image",
    onClick: onScan
  }, "Import a photo"))), /*#__PURE__*/React.createElement("div", {
    className: "kit-section"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, "Recent")), /*#__PURE__*/React.createElement(__ds_scope.Card, {
    flush: true
  }, pending ? /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Today, 12:50 PM",
    detail: "3 new \xB7 3 already logged",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      tone: "warn"
    }, "Needs review"),
    chevron: true,
    onClick: onReview
  }) : /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Today, 12:50 PM",
    detail: "Entries saved",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      tone: "ok"
    }, "Confirmed"),
    chevron: true
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Today, 11:02 AM",
    detail: "3 entries saved",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      tone: "ok"
    }, "Confirmed"),
    chevron: true
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Tue, Nov 24",
    detail: "11 entries saved \xB7 2 photos",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      tone: "ok"
    }, "Confirmed"),
    chevron: true
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Mon, Nov 23",
    detail: "12 entries saved \xB7 2 photos",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Badge, {
      tone: "ok"
    }, "Confirmed"),
    chevron: true
  }))));
}
function ReviewScreen({
  onCancel,
  onSave
}) {
  const [sel, setSel] = React.useState('s5');
  const [inc, setInc] = React.useState(() => {
    const m = {};
    __ds_scope.DRAFTS.forEach(d => {
      m[d.id] = d.status === 'create' && !d.suggestion;
    });
    return m;
  });
  const [res, setRes] = React.useState({});
  const listRef = React.useRef(null);
  React.useEffect(() => {
    const box = listRef.current;
    const el = box && box.querySelector('.bl-draft.is-selected');
    if (el) box.scrollTop = Math.max(0, el.offsetTop - box.offsetTop - 44);
  }, []);
  const rank = d => d.options ? 0 : d.status === 'skip_duplicate' ? 3 : d.suggestion ? 2 : 1;
  const ordered = __ds_scope.DRAFTS.slice().sort((a, b) => rank(a) - rank(b) || a.t - b.t);
  const hot = (__ds_scope.DRAFTS.find(d => d.id === sel) || {}).row;
  const chosen = __ds_scope.DRAFTS.filter(d => inc[d.id]);
  const open = chosen.filter(d => d.options && !res[d.id]).length;
  const save = () => onSave(chosen.map(d => Object.assign({
    type: d.type,
    t: res[d.id] === '11:30 AM' ? 690 : d.t,
    title: d.title,
    detail: d.saved || d.detail,
    source: 'paper_scan'
  }, d.ev)));
  return /*#__PURE__*/React.createElement("div", {
    className: "rv"
  }, /*#__PURE__*/React.createElement("div", {
    className: "rv-photo"
  }, /*#__PURE__*/React.createElement("div", {
    className: "rv-paper"
  }, /*#__PURE__*/React.createElement("div", {
    className: "rv-paper__head"
  }, /*#__PURE__*/React.createElement("b", null, "Blythe's Daily Log"), /*#__PURE__*/React.createElement("span", null, "Wed 11/25")), ROWS.map(r => /*#__PURE__*/React.createElement("div", {
    key: r.k,
    className: 'rv-line' + (r.k === hot ? ' is-hot' : '')
  }, /*#__PURE__*/React.createElement("span", {
    className: "rv-line__label"
  }, r.label, (r.pills || []).map(p => /*#__PURE__*/React.createElement("i", {
    key: p
  }, p))), /*#__PURE__*/React.createElement("span", {
    className: "rv-line__target"
  }, r.target), /*#__PURE__*/React.createElement("span", {
    className: "rv-line__hand"
  }, r.hand)))), /*#__PURE__*/React.createElement("div", {
    className: "rv-bar"
  }, /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Cancel review",
    variant: "outline",
    onClick: onCancel
  }), /*#__PURE__*/React.createElement(__ds_scope.Badge, null, "Today, 12:50 PM"))), /*#__PURE__*/React.createElement("div", {
    className: "kit-scroll rv-list",
    ref: listRef
  }, /*#__PURE__*/React.createElement("div", {
    className: "kit-section"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, __ds_scope.DRAFTS.length, " entries found"), /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, chosen.length, " selected")), /*#__PURE__*/React.createElement("div", {
    className: "kit-stack"
  }, ordered.map(d => /*#__PURE__*/React.createElement(__ds_scope.DraftCard, {
    key: d.id,
    type: d.type,
    time: res[d.id] || d.time,
    title: d.title,
    detail: d.detail,
    status: d.status,
    suggestion: d.suggestion,
    included: inc[d.id],
    onToggle: v => setInc(Object.assign({}, inc, {
      [d.id]: v
    })),
    selected: sel === d.id,
    onSelect: () => setSel(d.id),
    ambiguity: d.options && !res[d.id] ? d.ambiguity : null,
    options: d.options,
    onResolve: o => setRes(Object.assign({}, res, {
      [d.id]: o
    }))
  })))), /*#__PURE__*/React.createElement("div", {
    className: "rv-foot"
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "lg",
    block: true,
    disabled: !chosen.length || open > 0,
    onClick: save
  }, open ? open + (open === 1 ? ' entry needs' : ' entries need') + ' a look' : 'Save ' + chosen.length + (chosen.length === 1 ? ' entry' : ' entries'))));
}
Object.assign(__ds_scope, { SheetsScreen, ReviewScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/ScanScreens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/SettingsScreen.jsx
try { (() => {
function Group({
  title,
  children
}) {
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    className: "kit-section"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, title)), /*#__PURE__*/React.createElement(__ds_scope.Card, {
    flush: true
  }, children));
}
function SettingsScreen({
  theme,
  onToggleTheme,
  unit,
  onUnit,
  onAction
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-view"
  }, /*#__PURE__*/React.createElement("header", {
    className: "kit-head"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    className: "bl-label"
  }, "Blythe's household"), /*#__PURE__*/React.createElement("h1", {
    className: "kit-title"
  }, "Settings"))), /*#__PURE__*/React.createElement("div", {
    className: "kit-scroll"
  }, /*#__PURE__*/React.createElement(Group, {
    title: "Nap schedule"
  }, /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Awake before nap 1",
    value: "2\xBDh",
    chevron: true,
    onClick: () => onAction('Wake window editor opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Awake before nap 2",
    value: "3\xBCh",
    chevron: true,
    onClick: () => onAction('Wake window editor opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Nap cap",
    value: "90m",
    chevron: true,
    onClick: () => onAction('Nap cap editor opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Backup catnap cutoff",
    value: "4:30 PM",
    chevron: true,
    onClick: () => onAction('Cutoff editor opens here')
  })), /*#__PURE__*/React.createElement(Group, {
    title: "Logging"
  }, /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Bottle unit",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
      size: "sm",
      options: ['oz', 'mL'],
      value: unit,
      onChange: onUnit
    })
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Night mode",
    detail: "True black with warm, dim text",
    trailing: /*#__PURE__*/React.createElement(__ds_scope.Switch, {
      checked: theme === 'night',
      onChange: onToggleTheme,
      label: "Night mode"
    })
  })), /*#__PURE__*/React.createElement(Group, {
    title: "Household"
  }, /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    icon: "users",
    label: "Members",
    value: "3",
    chevron: true,
    onClick: () => onAction('Member list opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    icon: "key-round",
    label: "Invite code",
    value: "482 913"
  })), /*#__PURE__*/React.createElement(Group, {
    title: "Your data"
  }, /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    icon: "download",
    label: "Import from Huckleberry",
    detail: "CSV. Re-importing never duplicates.",
    chevron: true,
    onClick: () => onAction('File picker opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    icon: "upload",
    label: "Export everything",
    detail: "JSON bundle you can re-import",
    chevron: true,
    onClick: () => onAction('Share sheet opens here')
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    icon: "file-text",
    label: "Export for the pediatrician",
    detail: "Readable CSV",
    chevron: true,
    onClick: () => onAction('Share sheet opens here')
  })), /*#__PURE__*/React.createElement(Group, {
    title: "Account"
  }, /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Signed in with Apple"
  }), /*#__PURE__*/React.createElement(__ds_scope.ListRow, {
    label: "Sign out",
    danger: true,
    onClick: () => onAction('Signs out on this device only')
  }))));
}
Object.assign(__ds_scope, { SettingsScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/SettingsScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/TodayScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TILES = [['feeding', 'Bottle'], ['nursing', 'Nursing'], ['pump', 'Pump'], ['diaper', 'Diaper'], ['meal', 'Meal'], ['bath', 'Bath'], ['medicine', 'Meds'], ['note', 'Note']];
function TodayScreen({
  now,
  events,
  nap,
  nurse,
  pending,
  theme,
  onToggleTheme,
  onNap,
  onLog,
  onEdit,
  onReview
}) {
  const sorted = events.slice().sort((a, b) => b.t - a.t);
  const last = type => sorted.find(e => e.type === type);
  const napsDone = events.filter(e => e.nap).length;
  const ends = events.filter(e => e.type === 'sleep').map(e => e.end);
  const wakeAt = ends.length ? Math.max.apply(null, ends) : null;
  let hero;
  if (nap) {
    const el = now - nap.since,
      left = __ds_scope.SCHEDULE.napCap - el;
    hero = {
      state: 'asleep',
      label: 'Nap ' + (napsDone + 1) + ' · since ' + __ds_scope.clock(nap.since),
      elapsed: __ds_scope.dur(el),
      progress: el / __ds_scope.SCHEDULE.napCap,
      over: left < 0,
      actionLabel: 'Wake up',
      caption: /*#__PURE__*/React.createElement("span", null, "Nap cap ", /*#__PURE__*/React.createElement("b", null, __ds_scope.clock(nap.since + __ds_scope.SCHEDULE.napCap)), " \xB7 ", left < 0 ? __ds_scope.dur(-left) + ' over' : __ds_scope.dur(left) + ' left')
    };
  } else if (wakeAt == null) {
    hero = {
      state: 'awake',
      label: 'Awake',
      elapsed: '—',
      progress: 0,
      actionLabel: 'Start nap',
      caption: 'No sleep logged yet today'
    };
  } else {
    const isNap = napsDone < __ds_scope.SCHEDULE.windows.length;
    const target = isNap ? __ds_scope.SCHEDULE.windows[napsDone] : __ds_scope.SCHEDULE.bedtime;
    const name = isNap ? 'Nap ' + (napsDone + 1) : 'Bedtime';
    const el = now - wakeAt,
      left = target - el;
    hero = {
      state: 'awake',
      label: 'Awake · since ' + __ds_scope.clock(wakeAt),
      elapsed: __ds_scope.dur(el),
      progress: el / target,
      over: left < 0,
      actionLabel: isNap ? 'Start nap' : 'Start night sleep',
      caption: /*#__PURE__*/React.createElement("span", null, name, " sweet spot ", /*#__PURE__*/React.createElement("b", null, __ds_scope.clock(wakeAt + target)), " \xB7 ", left < 0 ? __ds_scope.dur(-left) + ' ago' : 'in ' + __ds_scope.dur(left))
    };
  }
  const feed = last('feeding'),
    diaper = last('diaper');
  const nursed = !!feed && feed.kind === 'nursing';
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-view"
  }, /*#__PURE__*/React.createElement("header", {
    className: "kit-head"
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    className: "bl-label"
  }, "Wednesday, Nov 25"), /*#__PURE__*/React.createElement("h1", {
    className: "kit-title"
  }, "Blythe ", /*#__PURE__*/React.createElement("span", null, "8 months"))), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: theme === 'night' ? 'sun' : 'moon',
    variant: "outline",
    label: "Toggle night mode",
    onClick: onToggleTheme
  })), /*#__PURE__*/React.createElement("div", {
    className: "kit-scroll"
  }, /*#__PURE__*/React.createElement(__ds_scope.NapCard, _extends({}, hero, {
    onAction: onNap,
    secondaryLabel: nap ? 'Change start time' : 'Add a past sleep',
    onSecondary: () => onLog('sleep')
  })), nurse ? /*#__PURE__*/React.createElement(__ds_scope.Card, {
    tone: "accent",
    onClick: () => onLog('nursing'),
    className: "kit-banner"
  }, /*#__PURE__*/React.createElement(__ds_scope.EventIcon, {
    type: "nursing"
  }), /*#__PURE__*/React.createElement("span", {
    className: "kit-banner__text"
  }, /*#__PURE__*/React.createElement("b", null, "Nursing \xB7 ", __ds_scope.mmss(__ds_scope.nurseSecs(nurse).total)), /*#__PURE__*/React.createElement("span", null, nurse.active ? (nurse.active === 'left' ? 'Left' : 'Right') + ' side running' : 'Paused', " \xB7 tap to switch or finish")), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 18
  })) : null, /*#__PURE__*/React.createElement("div", {
    className: "kit-glance"
  }, /*#__PURE__*/React.createElement(__ds_scope.GlanceStat, {
    type: nursed ? 'nursing' : 'feeding',
    label: "Last feed",
    value: feed ? __ds_scope.dur(now - feed.t) : '—',
    sub: feed ? (nursed ? 'Nursed ' : '') + feed.detail : 'None today',
    onClick: () => onLog(nursed ? 'nursing' : 'feeding')
  }), /*#__PURE__*/React.createElement(__ds_scope.GlanceStat, {
    type: "diaper",
    label: "Last diaper",
    value: diaper ? __ds_scope.dur(now - diaper.t) : '—',
    sub: diaper ? diaper.detail : 'None today',
    onClick: () => onLog('diaper')
  })), pending ? /*#__PURE__*/React.createElement(__ds_scope.Card, {
    tone: "accent",
    onClick: onReview,
    className: "kit-banner"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "scan-text",
    size: 22
  }), /*#__PURE__*/React.createElement("span", {
    className: "kit-banner__text"
  }, /*#__PURE__*/React.createElement("b", null, "Grandma's sheet, 12:50 PM"), /*#__PURE__*/React.createElement("span", null, "3 new entries to review")), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 18
  })) : null, /*#__PURE__*/React.createElement("div", {
    className: "kit-section"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, "Today"), /*#__PURE__*/React.createElement("span", {
    className: "bl-label"
  }, events.length, " entries \xB7 tap to edit")), /*#__PURE__*/React.createElement("div", {
    className: "kit-timeline"
  }, sorted.map(e => /*#__PURE__*/React.createElement(__ds_scope.EventRow, {
    key: e.id,
    type: e.kind || e.type,
    time: __ds_scope.clock(e.t),
    title: e.title,
    detail: e.detail,
    source: e.source,
    onClick: () => onEdit(e)
  })))), /*#__PURE__*/React.createElement("div", {
    className: "kit-dock"
  }, TILES.map(t => /*#__PURE__*/React.createElement(__ds_scope.QuickTile, {
    key: t[0],
    size: "sm",
    type: t[0],
    label: t[1],
    onClick: () => onLog(t[0])
  }))));
}
Object.assign(__ds_scope, { TodayScreen });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/TodayScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios/BlythesLifeApp.jsx
try { (() => {
function BlythesLifeApp() {
  const t0 = React.useRef(Date.now());
  const [, tick] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => tick(n => n + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const now = __ds_scope.BASE_NOW + (Date.now() - t0.current) / 60000;
  const [tab, setTab] = React.useState('today');
  const [theme, setTheme] = React.useState('day');
  const [unit, setUnit] = React.useState('oz');
  const [events, setEvents] = React.useState(__ds_scope.INITIAL_EVENTS);
  const [nap, setNap] = React.useState(null);
  const [nurse, setNurse] = React.useState(null); // { startedAt, left, right, active, since }
  const [sheet, setSheet] = React.useState({
    type: 'feeding',
    open: false,
    edit: null
  });
  const [pending, setPending] = React.useState(true);
  const [review, setReview] = React.useState(false);
  const [toast, setToast] = React.useState({
    open: false,
    message: '',
    undo: false
  });
  const undoRef = React.useRef(null);
  const timer = React.useRef(null);
  const hush = () => setToast(t => Object.assign({}, t, {
    open: false
  }));
  const say = (message, undo) => {
    undoRef.current = undo || null;
    setToast({
      open: true,
      message: message,
      undo: !!undo
    });
    clearTimeout(timer.current);
    timer.current = setTimeout(hush, 4500);
  };
  const closeSheet = () => setSheet(s => Object.assign({}, s, {
    open: false
  }));
  const openSheet = type => {
    hush();
    setSheet({
      type: type,
      open: true,
      edit: null
    });
  };
  const openEdit = e => {
    hush();
    setSheet({
      type: e.kind === 'nursing' ? 'nursing' : e.type,
      open: true,
      edit: e
    });
  };
  const openReview = () => {
    hush();
    setReview(true);
  };
  const add = (list, message) => {
    const stamped = list.map((e, i) => Object.assign({
      id: 'n' + Date.now() + i,
      source: 'manual'
    }, e));
    const ids = stamped.map(e => e.id);
    setEvents(ev => ev.concat(stamped));
    say(message, () => setEvents(ev => ev.filter(e => ids.indexOf(e.id) < 0)));
  };
  const update = (id, patch, message) => {
    const prev = events.find(e => e.id === id);
    closeSheet();
    setEvents(ev => ev.map(e => e.id === id ? Object.assign({}, e, patch) : e));
    say(message, () => setEvents(ev => ev.map(e => e.id === id ? prev : e)));
  };
  const remove = entry => {
    closeSheet();
    setEvents(ev => ev.filter(e => e.id !== entry.id));
    say(entry.title + ' deleted', () => setEvents(ev => ev.concat([entry])));
  };
  const toggleNap = () => {
    if (!nap) {
      setNap({
        since: now
      });
      say('Nap timer started on every device', () => setNap(null));
      return;
    }
    const n = events.filter(e => e.nap).length + 1;
    add([{
      type: 'sleep',
      nap: true,
      t: nap.since,
      start: nap.since,
      end: now,
      title: 'Nap ' + n,
      detail: __ds_scope.range(nap.since, now) + ' · ' + __ds_scope.dur(now - nap.since)
    }], 'Nap ' + n + ' saved');
    setNap(null);
  };

  // Tap a side to start; tap the running side to pause; tap the other side to switch.
  const nurseSide = side => {
    const ms = Date.now();
    if (!nurse) {
      setNurse({
        startedAt: now,
        left: 0,
        right: 0,
        active: side,
        since: ms
      });
      return;
    }
    const s = __ds_scope.nurseSecs(nurse);
    setNurse(Object.assign({}, nurse, {
      left: s.left,
      right: s.right,
      active: nurse.active === side ? null : side,
      since: ms
    }));
  };
  const finishNurse = () => {
    const s = __ds_scope.nurseSecs(nurse),
      m = x => Math.max(1, Math.round(x / 60));
    const both = s.left > 0 && s.right > 0,
      side = both ? 'Both' : s.left > 0 ? 'Left' : 'Right';
    const lm = m(s.left),
      rm = m(s.right);
    const total = both ? lm + rm : m(s.total);
    const detail = total + 'm · ' + (both ? 'Left ' + lm + 'm, Right ' + rm + 'm' : side + ' side');
    closeSheet();
    setNurse(null);
    add([{
      type: 'feeding',
      kind: 'nursing',
      t: nurse.startedAt,
      min: total,
      title: 'Nursing',
      detail: detail,
      form: {
        minutes: String(total),
        side: side
      }
    }], 'Nursing logged · ' + total + 'm');
  };
  const discardNurse = () => {
    const s = __ds_scope.nurseSecs(nurse);
    const paused = Object.assign({}, nurse, {
      left: s.left,
      right: s.right,
      active: null
    });
    closeSheet();
    setNurse(null);
    say('Nursing timer discarded', () => setNurse(paused));
  };
  const toggleTheme = () => setTheme(t => t === 'night' ? 'day' : 'night');
  const scan = () => pending ? openReview() : say('The camera opens here in the app');
  return /*#__PURE__*/React.createElement(__ds_scope.PhoneFrame, {
    theme: theme
  }, tab === 'today' ? /*#__PURE__*/React.createElement(__ds_scope.TodayScreen, {
    now: now,
    events: events,
    nap: nap,
    nurse: nurse,
    pending: pending,
    theme: theme,
    onToggleTheme: toggleTheme,
    onNap: toggleNap,
    onLog: openSheet,
    onEdit: openEdit,
    onReview: openReview
  }) : null, tab === 'rhythm' ? /*#__PURE__*/React.createElement(__ds_scope.RhythmScreen, {
    now: now,
    events: events,
    nap: nap
  }) : null, tab === 'sheets' ? /*#__PURE__*/React.createElement(__ds_scope.SheetsScreen, {
    pending: pending,
    onScan: scan,
    onReview: openReview
  }) : null, tab === 'settings' ? /*#__PURE__*/React.createElement(__ds_scope.SettingsScreen, {
    theme: theme,
    onToggleTheme: toggleTheme,
    unit: unit,
    onUnit: setUnit,
    onAction: m => say(m)
  }) : null, /*#__PURE__*/React.createElement(__ds_scope.TabBar, {
    value: tab,
    onChange: setTab,
    items: [{
      id: 'today',
      label: 'Today',
      icon: 'sun'
    }, {
      id: 'rhythm',
      label: 'Rhythm',
      icon: 'calendar-range'
    }, {
      id: 'sheets',
      label: 'Sheets',
      icon: 'scan-text',
      badge: pending ? 1 : null
    }, {
      id: 'settings',
      label: 'Settings',
      icon: 'settings'
    }]
  }), /*#__PURE__*/React.createElement("div", {
    className: "kit-home"
  }), review ? /*#__PURE__*/React.createElement(__ds_scope.ReviewScreen, {
    onCancel: () => setReview(false),
    onSave: list => {
      setReview(false);
      setPending(false);
      add(list, list.length + (list.length === 1 ? ' entry' : ' entries') + " saved from Grandma's sheet");
    }
  }) : null, /*#__PURE__*/React.createElement(__ds_scope.LogSheet, {
    type: sheet.type,
    open: sheet.open,
    edit: sheet.edit,
    now: now,
    unit: unit,
    nap: nap,
    nurse: nurse,
    napsDone: events.filter(e => e.nap).length,
    onClose: closeSheet,
    onSave: (list, message) => {
      closeSheet();
      add(list, message);
    },
    onUpdate: update,
    onDelete: remove,
    onNapStart: since => {
      closeSheet();
      setNap({
        since: since
      });
      say('Nap start set to ' + __ds_scope.clock(since));
    },
    onNurseSide: nurseSide,
    onNurseFinish: finishNurse,
    onNurseDiscard: discardNurse
  }), /*#__PURE__*/React.createElement(__ds_scope.Toast, {
    open: toast.open,
    message: toast.message,
    actionLabel: toast.undo ? 'Undo' : null,
    onAction: () => {
      if (undoRef.current) undoRef.current();
      hush();
    },
    style: {
      bottom: tab === 'today' ? 252 : 94
    }
  }));
}
Object.assign(__ds_scope, { BlythesLifeApp });
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios/BlythesLifeApp.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.ListRow = __ds_scope.ListRow;

__ds_ns.AmountField = __ds_scope.AmountField;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TextField = __ds_scope.TextField;

__ds_ns.TimeField = __ds_scope.TimeField;

__ds_ns.Sheet = __ds_scope.Sheet;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.DraftCard = __ds_scope.DraftCard;

__ds_ns.EVENT_TYPES = __ds_scope.EVENT_TYPES;

__ds_ns.EventIcon = __ds_scope.EventIcon;

__ds_ns.EventRow = __ds_scope.EventRow;

__ds_ns.GlanceStat = __ds_scope.GlanceStat;

__ds_ns.NapCard = __ds_scope.NapCard;

__ds_ns.NursingTimer = __ds_scope.NursingTimer;

__ds_ns.QuickTile = __ds_scope.QuickTile;

__ds_ns.BlythesLifeApp = __ds_scope.BlythesLifeApp;

__ds_ns.BASE_NOW = __ds_scope.BASE_NOW;

__ds_ns.SCHEDULE = __ds_scope.SCHEDULE;

__ds_ns.INITIAL_EVENTS = __ds_scope.INITIAL_EVENTS;

__ds_ns.DRAFTS = __ds_scope.DRAFTS;

__ds_ns.LogSheet = __ds_scope.LogSheet;

__ds_ns.PhoneFrame = __ds_scope.PhoneFrame;

__ds_ns.RhythmScreen = __ds_scope.RhythmScreen;

__ds_ns.SheetsScreen = __ds_scope.SheetsScreen;

__ds_ns.ReviewScreen = __ds_scope.ReviewScreen;

__ds_ns.SettingsScreen = __ds_scope.SettingsScreen;

__ds_ns.TodayScreen = __ds_scope.TodayScreen;

})();
