//
//  Commander.swift
//  PMS
//
//  Created by Yuki Takei on 6/25/16.
//
//

import CLibUv

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import String

public struct Option {
    let short: String
    let long: String
    let desc: String
    
    init(short: Character, long: String, desc: String){
        self.short = String(short)
        self.long = long
        self.desc = desc
    }
}

extension Option: CustomStringConvertible {
    public var description: String {
        return "\(short), \(long) \(desc)"
    }
}

private var programs = [Program]()

public class Program {
    
    enum Error: ErrorProtocol {
        case commandIsEmpty
        case subCommandsShouldSurroundWithBlacket
    }
    
    private var command: String
    
    private var subCommands = [String]()
    
    private var options: [Option]
    
    private var handler: ([String: String], [String: String]) throws -> Void = { _ in }
    
    public init(command: String, options: [Option]) throws {
        let cmds = command.split(separator: " ")
        guard cmds.count > 0 else {
            throw Error.commandIsEmpty
        }
        self.command =  cmds[0]
        
        subCommands = try Array(cmds[1..<cmds.count]).map { sub -> String in
            guard let first = sub.characters.first, last = sub.characters.last where first == "<" && last == ">" else {
                throw Error.subCommandsShouldSurroundWithBlacket
            }
            return sub.substring(with: sub.index(after: sub.startIndex)..<sub.index(before: sub.endIndex))
        }
        
        self.options = options
        programs.append(self)
    }
    
    public func action(handler: ([String: String], [String: String]) throws -> Void) {
        self.handler = handler
    }
}

extension Program {
    static func parse(_ argv: [String]) {
        let _cmd: String? = argv.count > 1 ? argv[1] : nil
        guard let cmd = _cmd else {
            exit(1)
        }
        
//        let rusage = UnsafeMutablePointer<uv_rusage_t>(allocatingCapacity: sizeof(uv_rusage_t))
//        uv_getrusage(rusage)
//        print(rusage.pointee)
        
        print(OS.uptime())
        print(OS.cpus())
        
        //FS.createFile("")
        
        
//        for p in programs {
//            for o in p.options {
//                print(o)
//            }
//        }
        
        if let index = programs.map({ $0.command == cmd }).index(of: true) {
            let p = programs[index]
            
            let subCommads = Array(argv[2..<2+p.subCommands.count])
            let options = Array(argv[2+p.subCommands.count..<argv.count])
            
            var subCommandMap: [String: String] = [:]
            var optionMap: [String: String] = [:]
            
            for (i, elem) in subCommads.enumerated() {
                subCommandMap[p.subCommands[i]] = elem
            }
            
            // Parse options
            var i = 0
            while(true) {
                if options.count <= i {
                    break
                }
                
                let o = options[i]
                
                if(o.substring(to: o.index(o.startIndex, offsetBy: 2)) == "--") {
                    let seg = o.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
                    let key = seg[0].substring(from: seg[0].index(seg[0].startIndex, offsetBy: 2))
                    if seg.count > 1 {
                        optionMap[key] = seg[1]
                    } else {
                        optionMap[key] = "1"
                    }
                }
                else if(o.characters.first == "-") {
                    let key = o.substring(from: o.index(o.startIndex, offsetBy: 1))
                    i = i+1
                    optionMap[key] = options[i]
                }
                i = i+1
            }
            
            var parsedOpts: [String: String] = [:]
            
            for (k, v) in optionMap {
                var flag=false
                for option in p.options {
                    if option.short == k {
                        flag=true
                        parsedOpts[option.short] = v
                        break
                    }
                    
                    let seg = option.long.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    if seg.count > 0 && seg[0] == k {
                        flag=true
                        parsedOpts[option.short] = v
                        break
                    }
                }
                if !flag {
                    print("`\(k)` is not valid otpion")
                    exit(1)
                }
            }
            
            do {
                try p.handler(subCommandMap, parsedOpts)
            } catch {
                print(error)
                exit(1)
            }
        }
    }
}
