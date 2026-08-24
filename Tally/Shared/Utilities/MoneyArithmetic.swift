//
//  MoneyArithmetic.swift
//  Tally
//

enum MoneyArithmetic {
    /// 对金额序列进行饱和求和，避免异常数据触发整数溢出崩溃。
    static func sum<S: Sequence>(_ values: S) -> Int64 where S.Element == Int64 {
        values.reduce(into: 0) { result, value in
            let (sum, overflow) = result.addingReportingOverflow(value)
            guard overflow else {
                result = sum
                return
            }
            result = value >= 0 ? .max : .min
        }
    }

    /// 对两个金额进行饱和减法，结余异常大时仍保持可显示状态。
    static func subtract(_ subtrahend: Int64, from minuend: Int64) -> Int64 {
        let (difference, overflow) = minuend.subtractingReportingOverflow(subtrahend)
        guard overflow else { return difference }
        return subtrahend < 0 ? .max : .min
    }
}
