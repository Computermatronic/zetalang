/* 
 * Reference implementation of the zeta-lang scripting language.
 * Copyright (c) 2015-2021 by Sean Campbell.
 * Written by Sean Campbell.
 * Distributed under The MPL-2.0 license (See LICENCE file).
 */
module zeta.type.string_t;

import zeta.type.type_t;
import zeta.script.interpreter;
import zeta.utils.error;
import zeta.script.exception;
import zeta.type;

class ZtStringType : ZtType {
    ZtScriptInterpreter interpreter;

    ZtValue make(string value) {
        ZtValue result;
        result.type = this;
        result.m_string = value;
        return result;
    }

    override void register(ZtScriptInterpreter interpreter) { this.interpreter= interpreter; }

    override @property string name() { return "string"; }
    
    override @property string op_tostring(ZtValue* self) {
        return "\"" ~ self.m_string ~ "\"";
    }

    override bool op_eval(ZtValue* self) {
        return self.m_string.length > 0 && self.m_string != "false";
    }

    override ZtValue op_cast(ZtValue* self, ZtType type) {
        import std.conv : to;
        if (type == this) return self.deRefed;
        else if (type == interpreter.integerType) return interpreter.integerType.make(self.m_string.to!int());
        else if (type == interpreter.floatType) return interpreter.floatType.make(self.m_string.to!float());
        else return super.op_cast(self, type);
    }

    override bool op_equal(ZtValue* self, ZtValue rhs) {
        if (rhs.type == this) return self.m_string == rhs.m_string;
        else if (rhs.type == interpreter.nullType) return self.m_string.length == 0;
        else return false;
    }

    override ZtValue op_index(ZtValue* self, ZtValue[] args) {
        if (args.length != 1 || args[0].type != interpreter.integerType) return super.op_index(self, args);
        auto index = args[0].m_int;
        if (index < 0 || index > self.m_string.length) throw new RuntimeException("Out of bounds argument for string index");
        return make(self.m_string[index .. index + 1]);
    }

    override ZtValue op_dispatch(ZtValue* self, string id) {
        switch(id) {
            case "length": return interpreter.integerType.make(cast(int)self.m_string.length);
            default: return super.op_dispatch(self, id);
        }
    }

    override ZtValue op_concat(ZtValue* self, ZtValue rhs) {
        if (rhs.type != this) super.op_concat(self, rhs);
        return make(self.m_string ~ rhs.m_string);
    }

    override void op_concatAssign(ZtValue* self, ZtValue rhs) {
        if (rhs.type != this) super.op_concat(self, rhs);
        self.m_string ~= rhs.m_string;
    }
}
