//
//  TableSetupView.swift
//  penteLive
//
//  Created by rainwolf on 06/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class TableSetupView: UITableView, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    var table: Table
    var socket: PenteLiveSocket!
    var gameCell, initialMinutesCell, incrementalSecondsCell: InputPickerCell?
    var ratedCell, timedCell, privateCell: UITableViewCell!
    var me: String

    init(table: Table, socket: PenteLiveSocket, me: String) {
        self.table = table
        self.socket = socket
        self.me = me
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: UITableView.Style.plain)
        delegate = self
        dataSource = self
        layer.borderWidth = 1.0
        layer.cornerRadius = 1.0
    }

    required init(coder aDecoder: NSCoder) {
        table = Table(table: 1)
        me = "guest"
        super.init(coder: aDecoder)!
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 6
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var idx = 0
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "gameCell") as? InputPickerCell ?? InputPickerCell(style: .value1, reuseIdentifier: "gameCell")
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
            var game = table.game
            if game % 2 == 0 {
                game = game - 1
            }
            cell.textField.text = table.gameNames[game]
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "privateCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "privateCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Table type:", comment: "")

            if table.open {
                cell.detailTextLabel?.text = NSLocalizedString("public", comment: "")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("private", comment: "")
            }

            privateCell = cell

            return cell
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ratedCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "ratedCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Rated:", comment: "")

            if table.rated {
                cell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            }

            ratedCell = cell

            return cell
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "timedCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "timedCell")
            cell.selectionStyle = .none
            cell.textLabel?.text = NSLocalizedString("Timed:", comment: "")

            if table.timed {
                cell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            } else {
                cell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            }

            timedCell = cell

            return cell
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "initialMinutesCell") as? InputPickerCell ?? InputPickerCell(style: .value1, reuseIdentifier: "initialMinutesCell")
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
            cell.textField.text = "\(table.timer["initialMinutes"]!)"
            minutesPicker.selectRow(table.timer["initialMinutes"]!, inComponent: 0, animated: true)
            cell.textField.inputView = minutesPicker
            cell.textField.tag = 1
            cell.textField.delegate = self
            cell.textField.inputAccessoryView = pickerToolbar

            initialMinutesCell = cell

            return cell
        }
        idx = idx + 1
        if indexPath.row == idx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "incrementalSecondsCell") as? InputPickerCell ?? InputPickerCell(style: .value1, reuseIdentifier: "incrementalSecondsCell")
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
            cell.textField.text = "\(table.timer["incrementalSeconds"]!)"
            secondsPicker.selectRow(table.timer["incrementalSeconds"]!, inComponent: 0, animated: true)
            cell.textField.inputView = secondsPicker
            cell.textField.tag = 1
            cell.textField.delegate = self
            cell.textField.inputAccessoryView = pickerToolbar

            incrementalSecondsCell = cell

            return cell
        }
        return UITableViewCell()
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {}
        if indexPath.row == 1 {
            if privateCell.detailTextLabel?.text == "public" {
                privateCell.detailTextLabel?.text = "private"
                table.open = false
            } else {
                privateCell.detailTextLabel?.text = "public"
                table.open = true
            }
            updateSettings()
        }
        if indexPath.row == 2 {
            if ratedCell.detailTextLabel?.text == NSLocalizedString("yes", comment: "") {
                table.rated = false
                ratedCell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            } else {
                table.rated = true
                ratedCell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            }
            updateSettings()
        }
        if indexPath.row == 3 {
            if timedCell.detailTextLabel?.text == NSLocalizedString("yes", comment: "") {
                table.timed = false
                timedCell.detailTextLabel?.text = NSLocalizedString("no", comment: "")
            } else {
                table.timed = true
                timedCell.detailTextLabel?.text = NSLocalizedString("yes", comment: "")
            }
            updateSettings()
        }
    }

    @objc func dismissPickers() {
        gameCell?.textField.resignFirstResponder()
        initialMinutesCell?.textField.resignFirstResponder()
        incrementalSecondsCell?.textField.resignFirstResponder()
        updateSettings()
    }

    func numberOfComponents(in _: UIPickerView) -> Int {
//        if pickerView.tag == 1 {
//            return 1
//        }
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        if pickerView.tag == 1 {
            return table.gameNames.count / 2
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
            return table.gameNames[row * 2 + 1]
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
            gameCell?.textField.text = table.gameNames[row * 2 + 1]
            table.game = row * 2 + 1
        }
        if pickerView.tag == 2 {
            initialMinutesCell?.textField.text = "\(row)"
            table.timer.updateValue(row, forKey: "initialMinutes")
        }
        if pickerView.tag == 3 {
            incrementalSecondsCell?.textField.text = "\(row)"
            table.timer.updateValue(row, forKey: "incrementalSeconds")
        }
    }

    func updateSettings() {
        var tableType = 2
        if table.open {
            tableType = 1
        }
        let event = ["dsgChangeStateTableEvent": ["timed": table.timed,
                                                  "initialMinutes": table.timer["initialMinutes"]!,
                                                  "incrementalSeconds": table.timer["incrementalSeconds"]!,
                                                  "rated": table.rated, "game": table.game, "tableType": tableType,
                                                  "player": me, "table": table.table, "time": 0] as [String: Any]]
        socket.sendEvent(eventDictionary: event)
    }
}

@objc class InputPickerCell: UITableViewCell {
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
