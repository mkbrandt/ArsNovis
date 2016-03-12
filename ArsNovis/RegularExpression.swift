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
        pm = [regmatch_t](count: maxMatches, repeatedValue: regmatch_t())
        self.maxMatches = maxMatches
    }
    
    func matchesWithString(s: String) -> Bool {
        let status = Int(regexec(&re, s, maxMatches, &pm, 0))
        matchedString = s
        return status == 0
    }
    
    func substring(so: regoff_t, _ eo: regoff_t) -> String {
        if eo == so {
            return ""
        }
        var start = matchedString.characters.startIndex
        for _ in 0 ..< so {
            start = start.successor()
        }
        var end = start
        for _ in 0 ..< eo - so - 1 {
            end = end.successor()
        }
        let s = matchedString[start...end]
        return s
    }
    
    func match(n: Int) -> String? {
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
        let endIndex = regoff_t(matchedString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        return substring(pm[0].rm_eo, endIndex)
    }
}

