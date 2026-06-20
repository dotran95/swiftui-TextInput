//
//  Logger.swift
//  app
//
//  Created by dotn on 8/8/24.

import SwiftyBeaver
import RxSwift

let logger = AppLogger.share

final class AppLogger {

    static let share = AppLogger()

    private let log = SwiftyBeaver.self

    private init() {
        let console = ConsoleDestination()  // log to Xcode Console
#if DEBUG
        console.minLevel = .debug
#else
        console.minLevel = 0
#endif

        log.addDestination(console)
    }

    func debug(_ message: @autoclosure () -> Any,
               _ file: String = #file,
               _ function: String = #function,
               line: Int = #line) {
        log.debug(message(), file, function, line: line)
    }

    func info(_ message: @autoclosure () -> Any,
              _ file: String = #file,
              _ function: String = #function,
              line: Int = #line) {
        log.info(message(), file, function, line: line)
    }

    func error(_ message: @autoclosure () -> Any,
               _ file: String = #file,
               _ function: String = #function,
               line: Int = #line) {
        log.error(message(), file, function, line: line)
    }

    func verbose(_ message: @autoclosure () -> Any,
                 _ file: String = #file,
                 _ function: String = #function,
                 line: Int = #line) {
        log.verbose(message(), file, function, line: line)
    }

    func warning(_ message: @autoclosure () -> Any,
                 _ file: String = #file,
                 _ function: String = #function,
                 line: Int = #line) {
        log.warning(message(), file, function, line: line)
    }
}
