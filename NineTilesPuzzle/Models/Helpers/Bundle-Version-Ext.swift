//
//  Bundle-Version-Ext.swift
//
//  Created by Filippo Cilia on 8/5/26.
//

import Foundation

extension Bundle {
    var appVersionNumber: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var appBuildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
