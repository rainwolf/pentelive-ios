//
//  TableSetupView.swift
//  penteLive
//
//  Created by rainwolf on 06/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class ArenaTableSetupView: UITableView, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    var gameCell, initialMinutesCell, incrementalSecondsCell: ArenaInputPickerCell?
    var ratedCell, timedCell, playAsCell, submitCell: UITableViewCell!
    var me: String
    var data: [String: Any]?
    var socket: PenteLiveSocket!
    var popoverView: PopoverView?

    init(data: [String: Any], socket: PenteLiveSocket,  me: String) {
        self.me = me
        self.socket = socket
        self.data = data
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: UITableView.Style.plain)
        delegate = self
        dataSource = self
        layer.borderWidth = 1.0
        layer.cornerRadius = 1.0
    }

    required init(coder aDecoder: NSCoder) {
        me = "guest"
        super.init(coder: aDecoder)!
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        var rows = 4
        if data!["timed"] as? Bool ?? false {
            rows = rows + 2
        }
        if !(data!["rated"] as? Bool ?? false) {
            rows = rows + 1
        }
        return rows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var idx = 0
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "gameCell") as? ArenaInputPickerCell ?? ArenaInputPickerCell(style: .value1, reuseIdentifier: "gameCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Game:", comment: "")

            let gamePicker = UIPickerView()
            let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 44))
            pickerToolbar.isTranslucent = true
            let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(dismissPickers)) // method
            pickerToolbar.setItems([extraSpace, doneButton], animated: true)
            gamePicker.delegate = self
            gamePicker.dataSource = self
            gamePicker.tag = 1
            var game = data!["game"] as? Int ?? 1
            if game % 2 == 0 {
                game = game - 1
            }
            cell.textField.text = Table.gameNames[game]
            gamePicker.selectRow(game / 2, inComponent: 0, animated: true)

            cell.textField.inputView = gamePicker
            cell.textField.tag = 1
            cell.textField.delegate = self
            cell.textField.inputAccessoryView = pickerToolbar

            gameCell = cell

            return cell
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ratedCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "ratedCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Rated:", comment: "")

            if data!["rated"] as? Bool ?? false {
                cell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            }

            ratedCell = cell

            return cell
        }
        if !(data!["rated"] as? Bool ?? false) {
            idx = idx + 1
            if indexPath.row == idx {
                let cell = tableView.dequeueReusableCell(withIdentifier: "playAsCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "playAsCell")
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Play as:", comment: "")
                if data!["playAs"] as? Int == 2 {
                    cell.detailTextLabel?.text = NSLocalizedString("black", comment: "")
                } else if data!["playAs"] as? Int == 1 {
                    cell.detailTextLabel?.text = NSLocalizedString("white", comment: "")
                } else {
                    cell.detailTextLabel?.text = NSLocalizedString("uh-oh", comment: "")
                }
                playAsCell = cell
                return cell
            }
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "timedCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "timedCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Timed:", comment: "")

            if data!["timed"] as? Bool ?? false {
                cell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            }

            timedCell = cell

            return cell
        }
        if data!["timed"] as? Bool ?? false {
            idx = idx + 1
            if indexPath.row == idx {
                let cell = tableView.dequeueReusableCell(withIdentifier: "initialMinutesCell") as? ArenaInputPickerCell ?? ArenaInputPickerCell(style: .value1, reuseIdentifier: "initialMinutesCell")
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Initial minutes:", comment: "")
                
                let minutesPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 44))
                pickerToolbar.isTranslucent = true
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(dismissPickers)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                minutesPicker.delegate = self
                minutesPicker.dataSource = self
                minutesPicker.tag = 2
                cell.textField.text = "\(data!["initialMinutes"]!)"
                minutesPicker.selectRow(data!["initialMinutes"] as? Int ?? 0, inComponent: 0, animated: true)
                cell.textField.inputView = minutesPicker
                cell.textField.tag = 1
                cell.textField.delegate = self
                cell.textField.inputAccessoryView = pickerToolbar
                
                initialMinutesCell = cell
                
                return cell
            }
            idx = idx + 1
            if indexPath.row == idx {
                let cell = tableView.dequeueReusableCell(withIdentifier: "incrementalSecondsCell") as? ArenaInputPickerCell ?? ArenaInputPickerCell(style: .value1, reuseIdentifier: "incrementalSecondsCell")
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Incremental seconds:", comment: "")
                
                let secondsPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 44))
                pickerToolbar.isTranslucent = true
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(dismissPickers)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                secondsPicker.delegate = self
                secondsPicker.dataSource = self
                secondsPicker.tag = 3
                cell.textField.text = "\(data!["incrementalSeconds"]!)"
                secondsPicker.selectRow(data!["incrementalSeconds"] as? Int ?? 0, inComponent: 0, animated: true)
                cell.textField.inputView = secondsPicker
                cell.textField.tag = 1
                cell.textField.delegate = self
                cell.textField.inputAccessoryView = pickerToolbar
                
                incrementalSecondsCell = cell
                
                return cell
            }
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "submitCell") ?? UITableViewCell(style: .default, reuseIdentifier: "submitCell")
            cell.textLabel?.text = NSLocalizedString("Create table", comment: "")
            cell.textLabel?.textAlignment = .center
            cell.backgroundColor = .systemBlue
            submitCell = cell
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        var idx = 1
        if indexPath.row == idx {
            if me.hasPrefix("guest") {
                return
            }
            if ratedCell.detailTextLabel?.text == NSLocalizedString("yes", comment: "") {
                data?["rated"] = false
                ratedCell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            } else {
                data?["rated"] = true
                ratedCell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            }
            self.reloadData()
        }
        if !(data!["rated"] as? Bool ?? false) {
            idx = idx + 1
            if indexPath.row == idx {
                if playAsCell.detailTextLabel?.text == NSLocalizedString("black", comment: "") {
                    data?["playAs"] = 1
                    playAsCell.detailTextLabel?.text = NSLocalizedString("white", comment: "")
                } else if playAsCell.detailTextLabel?.text == NSLocalizedString("white", comment: "") {
                    data?["playAs"] = 2
                    playAsCell.detailTextLabel?.text = NSLocalizedString("black", comment: "")
                } else {
                    print("uh-oh")
                }
            }
        }
        idx = idx + 1
        if indexPath.row == idx {
            if timedCell.detailTextLabel?.text == NSLocalizedString("yes", comment: "") {
                data?["timed"] = false
                timedCell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            } else {
                data?["timed"] = true
                timedCell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            }
            self.reloadData()
        }
        if indexPath.row == self.tableView(self, numberOfRowsInSection: 0) - 1 {
            updateSettings()
        }
    }

    @objc func dismissPickers() {
        gameCell?.textField.resignFirstResponder()
        initialMinutesCell?.textField.resignFirstResponder()
        incrementalSecondsCell?.textField.resignFirstResponder()
    }

    func numberOfComponents(in _: UIPickerView) -> Int {
//        if pickerView.tag == 1 {
//            return 1
//        }
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        if pickerView.tag == 1 {
            return Table.gameNames.count / 2
        }
        if pickerView.tag == 2 {
            return 119
        }
        if pickerView.tag == 3 {
            return 60
        }
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent _: Int) -> String? {
        if pickerView.tag == 1 {
            return Table.gameNames[row * 2 + 1]
        }
        if pickerView.tag == 2 {
            return "\(row)"
        }
        if pickerView.tag == 3 {
            return "\(row)"
        }
        return "bunny"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        if pickerView.tag == 1 {
            gameCell?.textField.text = Table.gameNames[row * 2 + 1]
            data?["game"] = row * 2 + 1
        }
        if pickerView.tag == 2 {
            initialMinutesCell?.textField.text = "\(row)"
            data?["initialMinutes"] = row
        }
        if pickerView.tag == 3 {
            incrementalSecondsCell?.textField.text = "\(row)"
            data?["incrementalSeconds"] = row
        }
    }

    func updateSettings() {
        let event = ["dsgArenaCreateTableEvent": ["timed": data?["timed"] ?? false,
                                                  "initialMinutes": data?["initialMinutes"] ?? 0,
                                                  "incrementalSeconds": data?["incrementalSeconds"] ?? 0,
                                                  "rated": data?["rated"] ?? false,
                                                  "game": data?["game"] ?? 1,
                                                  "playAs": data?["playAs"] ?? 1,
                                                  "player": self.me, "table": -1, "time": 0] as [String: Any]]
//        print("updateSettings: \(event)")
        socket.sendEvent(eventDictionary: event)
        popoverView?.dismiss()
    }
}

@objc class ArenaInputPickerCell: UITableViewCell {
    @objc var textField: UITextField

    override required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        textField = UITextField()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textField.textAlignment = .right
        contentView.addSubview(textField)
    }

    required init(coder aDecoder: NSCoder) {
        textField = UITextField()
        super.init(coder: aDecoder)!
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let tfX: CGFloat = (textLabel?.frame.origin.x)! + (textLabel?.frame.size.width)! + 15
        let tfW = contentView.frame.size.width - tfX - 15
        textField.frame = CGRect(x: tfX, y: 4, width: tfW, height: 36)
    }
}
