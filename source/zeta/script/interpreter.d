/* 
 * Reference implementation of the zeta-lang scripting language.
 * Copyright (c) 2015-2021 by Sean Campbell.
 * Written by Sean Campbell.
 * Distributed under The MPL-2.0 license (See LICENCE file).
 */
module zeta.script.interpreter;

import std.conv : to;
import std.algorithm;
import std.array;
import std.container.slist;

import zeta.utils;
import zeta.parse;
import zeta.typesystem;
import zeta.script;

final class ZtScriptInterpreter {
    mixin(MultiDispatch!`evaluate`);
    mixin(MultiDispatch!`execute`);

    SList!ZtLexicalContext stack;
    ZtValue returnValue;
    bool isReturning;
    int continueLevel, breakLevel;

    ZtNullType nullType;
    ZtBoolType booleanType;
    ZtIntType integerType;
    ZtFloatType floatType;
    ZtStringType stringType;
    ZtArrayType arrayType;
    ZtFunctionType functionType;
    ZtNativeType nativeType;
    ZtMetaType metaType;
    ZtType[] types;

    this() {
        stack.insertFront(new ZtLexicalContext);
        types ~= nullType = new ZtNullType;
        types ~= booleanType = new ZtBoolType;
        types ~= integerType = new ZtIntType;
        types ~= floatType = new ZtFloatType;
        types ~= stringType = new ZtStringType;
        types ~= arrayType = new ZtArrayType;
        types ~= functionType = new ZtFunctionType;
        types ~= nativeType = new ZtNativeType;
        types ~= metaType = new ZtMetaType;

        foreach (k, v; types) {
            v.register(this);
            context.define(v.name, metaType.make(v));
        }
        context.define("true", booleanType.trueValue);
        context.define("false", booleanType.falseValue);
        context.define("null", nullType.nullValue);
    }

    @property ZtLexicalContext context() {
        return stack.front;
    }

    ZtLexicalContext execute(ZtAstModule node) {
        auto moduleScope = new ZtLexicalContext(context);
        stack.insertFront(moduleScope);
        execute(cast(ZtAstStatement[]) node.members);
        stack.removeFront();
        return moduleScope;
    }

    ZtValue evaluate(ZtClosure closure, ZtValue[] arguments) {
        auto oldReturnValue = returnValue;
        returnValue = nullType.nullValue;
        stack.insertFront(new ZtLexicalContext(closure.context));
        foreach (i, paramater; closure.node.paramaters) {
            bool isRef = paramater.attributes.canFind!((e) => e.name == "ref");
            if (closure.node.isVariadic && i + 1 == closure.node.paramaters.length) {
                context.define(paramater.name,
                        arrayType.make(arguments[i .. $].map!((e) => isRef ? e : e.deRefed()).array));
                break;
            }
            if (arguments.length > i)
                context.define(paramater.name, isRef ? arguments[i] : arguments[i].deRefed());
            else if (paramater.initializer !is null)
                context.define(paramater.name, isRef
                        ? evaluate(paramater.initializer) : evaluate(paramater.initializer)
                        .deRefed());
            else
                assert(0,
                        "Incorrect number of paramaters when calling function " ~ closure.node.name);
        }
        execute(closure.node.members);
        stack.removeFront();
        auto result = returnValue;
        returnValue = oldReturnValue;
        return result;
    }

    void execute(ZtAstStatement[] members) {
        foreach (member; members) {
            execute(member);
            if (isReturning || breakLevel || continueLevel)
                return;
        }
    }

    ZtValue[] evaluate(ZtAstExpression[] members) {
        return members.map!((e) => evaluate(e)).array;
    }

    void execute(ZtAstDef node) {
        if (node.initializer is null)
            context.define(node.name, nullType.nullValue);
        else
            context.define(node.name, evaluate(node.initializer).deRefed);
    }

    void execute(ZtAstImport node) {
        assert(0, "Not implemented!");
    }

    void execute(ZtAstFunction node) {
        context.define(node.name, functionType.make(node, context));
    }

    // void execute(ZtAstClass node) {
    //     auto classType = new ZtClassType(node, context);
    //     classType.register(this);
    //     types ~= classType;
    //     context.define(node.name, metaType.make(classType));
    // }

    void execute(ZtAstIf node) {
        stack.insertFront(new ZtLexicalContext(context));
        if (evaluate(node.condition).op_eval())
            execute(node.members);
        else
            execute(node.elseMembers);
        stack.removeFront();
    }

    void execute(ZtAstSwitch node) {
        stack.insertFront(new ZtLexicalContext(context));
        auto cond = evaluate(node.condition);
        bool isFallthrough = false;
        size_t elseCaseId;
        for (size_t i = 0; i < node.members.length; i++) {
            if (node.members[i].isElseCase)
                elseCaseId = i;
            auto matches = node.members[i].matches.any!((exp) => evaluate(exp).op_equal(cond));
            if (matches || isFallthrough) {
                execute(node.members[i].members);
                if (isReturning)
                    return;
                if (breakLevel > 0) {
                    stack.removeFront();
                    breakLevel--;
                    return;
                }
                if (continueLevel > 1) {
                    stack.removeFront();
                    continueLevel--;
                    return;
                }
                if (continueLevel == 1) {
                    stack.removeFront();
                    continueLevel--;
                    isFallthrough = false;
                }
                isFallthrough = true;
            }
            if (i + 1 == node.members.length && !isFallthrough && elseCaseId != 0) {
                i = elseCaseId - 1;
                isFallthrough = true;
                continue;
            }
        }
        stack.removeFront();
    }

    void execute(ZtAstWhile node) {
        stack.insertFront(new ZtLexicalContext(context));
        while (evaluate(node.condition).op_eval()) {
            stack.insertFront(new ZtLexicalContext(context));
            execute(node.members);
            if (breakLevel > 0) {
                stack.removeFront();
                breakLevel--;
                return;
            }
            if (continueLevel > 1) {
                stack.removeFront();
                continueLevel--;
                return;
            }
            if (continueLevel == 1) {
                stack.removeFront();
                continueLevel--;
                continue;
            }
            stack.removeFront();
        }
    }

    void execute(ZtAstDoWhile node) {
        do {
            stack.insertFront(new ZtLexicalContext(context));
            execute(node.members);
            if (breakLevel > 0) {
                stack.removeFront();
                breakLevel--;
                return;
            }
            if (continueLevel > 1) {
                stack.removeFront();
                continueLevel--;
                return;
            }
            if (continueLevel == 1) {
                stack.removeFront();
                continueLevel--;
                continue;
            }
            stack.removeFront();
        }
        while (evaluate(node.condition).op_eval());
    }

    void execute(ZtAstFor node) {
        stack.insertFront(new ZtLexicalContext(context));
        execute(node.initializer);
        for (; evaluate(node.condition).op_eval(); evaluate(node.step)) {
            stack.insertFront(new ZtLexicalContext(context));
            execute(node.members);
            if (breakLevel > 0) {
                stack.removeFront(2);
                breakLevel--;
                return;
            }
            if (continueLevel > 1) {
                stack.removeFront(2);
                continueLevel--;
                return;
            }
            if (continueLevel == 1) {
                stack.removeFront(2);
                continueLevel--;
                continue;
            }
            stack.removeFront();
        }
        stack.removeFront();
    }

    void execute(ZtAstForeach node) {
        assert(0, "Not implemented!");
    }

    void execute(ZtAstWith node) {
        stack.insertFront(new ZtWithContext(evaluate(node.aggregate), context));
        execute(node.members);
        stack.removeFront();
    }

    void execute(ZtAstReturn node) {
        returnValue = evaluate(node.expression);
        isReturning = true;
    }

    void execute(ZtAstBreak node) {
        breakLevel++;
    }

    void execute(ZtAstContinue node) {
        continueLevel++;
    }

    void execute(ZtAstExpressionStatement node) {
        evaluate(node.expression);
    }

    ZtValue evaluate(ZtAstIdentifier node) {
        return context.lookup(node.name);
    }

    ZtValue evaluate(ZtAstDispatch node) {
        return evaluate(node.expression).op_dispatch(node.name);
    }

    ZtValue evaluate(ZtAstSubscript node) {
        return evaluate(node.expression).op_index(evaluate(node.arguments));
    }

    ZtValue evaluate(ZtAstBinary node) {
        return evaluate(node.lhs).op_binary(node.operator, evaluate(node.rhs));
    }

    ZtValue evaluate(ZtAstLogical node) {
        bool result;
        auto lhs = evaluate(node.lhs);
        with(ZtAstLogical.Operator) final switch(node.operator) {
        case and:
            result = lhs.op_eval() && evaluate(node.rhs).op_eval();
            break;
        case or:
            result = lhs.op_eval() || evaluate(node.rhs).op_eval();
            break;
        case xor:
            result = lhs.op_eval() != evaluate(node.rhs).op_eval();
            break;
        case equal:
            result = lhs.op_equal(evaluate(node.rhs));
            break;
        case notEqual:
            result = !lhs.op_equal(evaluate(node.rhs));
            break;
        case lessThan:
            result = lhs.op_cmp(evaluate(node.rhs)) < 0;
            break;
        case greaterThan:
            result = lhs.op_cmp(evaluate(node.rhs)) > 0;
            break;
        case lessThanEqual:
            result = lhs.op_cmp(evaluate(node.rhs)) <= 0;
            break;
        case greaterThanEqual:
            result = lhs.op_cmp(evaluate(node.rhs)) >= 0;
            break;
        }
        return booleanType.make(result);
    }

    ZtValue evaluate(ZtAstUnary node) {
        auto rhs = evaluate(node.expression);
        if (node.operator == ZtAstUnary.Operator.not) return booleanType.make(!rhs.op_eval());
        if (node.isPostOp) {
            auto result = rhs.deRefed();
            rhs.op_unary(node.operator);
            return result;
        } else
            return rhs.op_unary(node.operator);
    }

    ZtValue evaluate(ZtAstTrinary node) {
        return evaluate(node.condition).op_eval ? evaluate(node.lhs) : evaluate(node.rhs);
    }

    ZtValue evaluate(ZtAstAssign node) {
        auto rhs = evaluate(node.rhs).deRefed();
        // if (auto identifier = cast(ZtAstIdentifier)node.lhs) {
        //     return rhs.deRefed();
        // } else if (auto dispatch = cast(ZtAstDispatch)node.lhs) {
        //     return rhs.deRefed();
        // } else if (auto index = cast(ZtAstSubscript)node.lhs) {
        //     return rhs.deRefed();
        // } else {
        //TODO: implement proper assignment behavior instead of relying on transparent references to do the heavy lifting.
        auto lhs = evaluate(node.lhs);
        assert(lhs.isRef, "Error: Cannot assign RValue");
        if (node.operator == ZtAstBinary.Operator.no_op) lhs = rhs;
        else lhs.op_assignBinary(node.operator, rhs);
        return rhs.deRefed();
        // }
    }

    ZtValue evaluate(ZtAstCall node) {
        auto fun = evaluate(node.expression);
        auto args = node.arguments.map!((n) => evaluate(n))().array;
        return fun.op_call(args);
    }

    ZtValue evaluate(ZtAstApply node) {
        auto lhs = evaluate(node.expression);
        if (lhs.type != nullType)
            return lhs.op_dispatch(node.name);
        else
            return nullType.nullValue;
    }

    ZtValue evaluate(ZtAstCast node) {
        auto result = evaluate(node.type);
        if (result.type == metaType)
            return evaluate(node.expression).op_cast(result.m_type);
        else
            return evaluate(node.expression).op_cast(result.type);
    }

    ZtValue evaluate(ZtAstIs node) {
        return booleanType.make(evaluate(node.lhs).type == evaluate(node.rhs).type);
    }

    ZtValue evaluate(ZtAstNew node) {
        auto result = evaluate(node.type);
        if (result.type == metaType)
            return result.m_type.op_new(evaluate(node.arguments));
        else
            assert(0, "Cannot instantise non-type");
    }

    ZtValue evaluate(ZtAstArray node) {
        return arrayType.make(evaluate(node.arguments));
    }

    ZtValue evaluate(ZtAstString node) {
        return stringType.make(node.literal);
    }

    ZtValue evaluate(ZtAstChar node) {
        return stringType.make(cast(string)[node.literal]);
    }

    ZtValue evaluate(ZtAstInteger node) {
        return integerType.make(node.literal);
    }

    ZtValue evaluate(ZtAstFloat node) {
        return floatType.make(node.literal);
    }
}
