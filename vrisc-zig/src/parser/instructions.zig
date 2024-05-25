pub const ROC = enum { reg, con };

pub const RegOrConst = union(ROC) {
    reg: u4,
    con: u64,
};

pub const Arithmetic = struct {
    goal: u4,
    first: RegOrConst,
    second: RegOrConst,
};

pub const Branching = struct {
    counter: u32,
};

pub const Compare = struct {
    left: u4,
    right: RegOrConst,
};

pub const Memory = struct {
    source: u4,
    address: RegOrConst,
};