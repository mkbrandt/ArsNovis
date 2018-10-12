//
//  RegExp.swift
//  Soloist
//
//  Created by Matt Brandt on 2/18/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Foundation

class RegularExpression
{
    var re = regex_t()
    var maxMatches = 0
    var pm: [regmatch_t]
    var matchedString: String = ""
    
    init(pattern: String, maxMatches: Int = 20) {
        regcomp(&re, pattern, REG_EXTENDED)
        pm = [regmatch_t](repeating: regmatch_t(), count: maxMatches)
        self.maxMatches = maxMatches
    }
    
    func matchesWithString(_ s: String) -> Bool {
        let status = Int(regexec(&re, s, maxMatches, &pm, 0))
        matchedString = s
        return status == 0
    }
    
    func substring(_ so: regoff_t, _ eo: regoff_t) -> String {
        if eo == so {
            return ""
        }
        var start = matchedString.startIndex
        for _ in 0 ..< so {
            start = matchedString.index(after: start)
        }
        var end = start
        for _ in 0 ..< eo - so - 1 {
            end = matchedString.index(after: end)
        }
        let s = matchedString[start...end]
        return s
    }
    
    func match(_ n: Int) -> String? {
        if n > maxMatches {
            return nil
        }
        let m = pm[n]
        if m.rm_so < 0 {
            return nil
        }
        if m.rm_so == m.rm_eo {
            return ""
        }
        return substring(m.rm_so, m.rm_eo)
    }
    
    var prefix: String {
        return substring(0, pm[0].rm_so)
    }
    
    var suffix: String {
        let endIndex = regoff_t(matchedString.lengthOfBytes(using: String.Encoding.utf8))
        return substring(pm[0].rm_eo, endIndex)
    }
}

