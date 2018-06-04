/* 
 * The official Zeta interpreter.
 * Reference implementation of the Zeta scripting language.
 * Copyright (c) 2018 by Sean Campbell.
 * Written by Sean Campbell.
 * Distributed under The MIT License (See LICENCE file).
 */
module zeta.interpreter.preprocessor;

import std.format : format;
import zeta.parser.ast;
import zeta.interpreter.context;
import zeta.runtime.core;

class Preprocessor : ASTVisitor {
	Runtime runtime;
	Context context;

	size_t withCount;

	this(Runtime runtime) {
		this.runtime = runtime;
	}

	Context pushContext() {
		return context = new Context(context);
	}

	void popContext() {
		context = context.outer;
	}

	void addError(Args...)(string fmt, Args args) {
		errors ~= format(fmt, args);
	}

	void visit(ModuleNode node) {
		if (!context.define(node.name, node))
			addError("[BUG] Double module declaration!");

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(ImportNode importNode) {
		
	}

	void visit(DefNode node) {
		if (!context.define(node.name, node))
			addError("Conflicting Symbol %s at %s and %s", node.location context.get(node.name).location);

		if (node.initializer) node.initializer.accept(this);
	}

	void visit(FunctionNode node) {
		if (!context.define(node.name, node))
			addError("Conflicting Symbol %s at %s and %s", node.location context.get(node.name).location);

		foreach(paramater; node.paramaters) {
			paramater.accept(this);
		}

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(ClassNode node) {
		//if (!context.define(node.name, node))
		//	addError("Conflicting Symbol %s at %s and %s", node.location context.get(node.name).location);
		//
		//foreach(inherit; node.inherits) {
		//	inherit.accept(this);
		//}
		//
		//foreach(member; node.members) {
		//	member.accept(this);
		//}
	}

	void visit(AttributeNode node) {
		foreach(argument; node.arguments) {
			argument.accept(this);
		}
	}

	void visit(FunctionParamaterNode node) {
		if (!context.define(node.name, node))
			addError("Conflicting Symbol %s at %s and %s", node.location context.get(node.name).location);

		if (node.initializer) node.initializer.accept(this);
	}

	void visit(IfNode node) {
		node.subject.accept(this);

		foreach(member; node.members) {
			member.accept(this);
		}

		if (node.else_) node.else_.accept(this);
	}

	void visit(ElseNode node) {
		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(SwitchNode node) {
		node.subject.accept(this);

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(SwitchCaseNode node) {
		foreach(argument; node.arguments) {
			argument.accept(this);
		}

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(ForNode node) {
		if (node.initializer) node.initializer.accept(this);
		if (node.subject) node.subject.accept(this);
		if (node.step) node.step.accept(this);

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(ForeachNode node) {
		foreach(initializer; node.initializers) {
			initializer.accept(this);
		}

		node.subject.accept(this);
		
		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(WhileNode node) {
		node.subject.accept(this);

		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(WithNode node) {
		node.subject.accept(this);

		withCount++;
		foreach(member; node.members) {
			member.accept(this);
		}
	}

	void visit(DoWhileNode node) {
		foreach(member; node.members) {
			member.accept(this);
		}

		node.subject.accept(this);
	}
	
	void visit(BreakNode node) {

	}
	
	void visit(ContinueNode node) {

	}

	void visit(ReturnNode node) {
		if (node.subject) node.subject.accept(this);
	}

	void visit(ExpressionStatementNode node) {
		node.subject.accept(this);
	}

	void visit(UnaryNode node) {
		node.subject.accept(this);

		final switch(node.operator) with(UnaryNode.Operator) {
			case increment:
				break;

			case decrement:
				break;

			case posative:
				break;

			case negative:
				break;

			case not:
				break;

			case bitwiseNot:
				break;

			case postIncrement:
				break;

			case postDecrement:
				break;
		}
	}

	void visit(BinaryNode node) {
		node.lhs.accept(this);

		final switch(node.operator) with(BinaryNode.Operator) {
			case multiply:
				break;

			case divide:
				break;

			case modulo:
				break;

			case add:
				break;

			case subtract:
				break

			case bitwiseShiftLeft:
				break;

			case bitwiseShiftRight:
				break;

			case greaterThan: 
				break;

			case lessThan:
				break;

			case greaterThanEqual: 
				break;

			case lessThanEqual:
				break;

			case bitwiseAnd:
				break;

			case bitwiseOr:
				break;

			case bitwiseXor:
				break;

			case and:
				break;

			case or:
				break;

			case xor:
				break;

			case slice:
				break;

			case concat:
				break;

			case equal:
				break;

			case notEqual:
				break;
		}

		node.rhs.accept(this);
	}

	void visit(TinaryNode node) {
		node.subject.accept(this);

		node.lhs.accept(this);

		node.rhs.accept(this);
	}

	void visit(FunctionCallNode node) {
		node.subject.accept(this);
		if(cast(IdentifierNode)node !is null) {
			
		}

		foreach(argument; node.arguments) {
			arguemnt.accept(this);
		}
	}

	void visit(NewNode node) {
		node.type.accept(this);

		foreach(argument; node.arguments) {
			arguemnt.accept(this);
		}
	}

	void visit(AssignmentNode node) {
		node.subject.accept(this);

		final switch(node.operator) with (AssignmentNode.Operator) {
			case assign:
				break;

			case add:
				break;

			case subtract:
				break;

			case multiply:
				break;

			case divide:
				break;

			case modulo:
				break;

			case concat:
				break;

			case and:
				break;

			case or:
				break;

			case xor:
				break;
		}

		node.argument.accept(this);
	}

	void visit(ArrayLiteralNode node) {
		foreach(value; node.value) {
			value.accept(this);
		}
	}

	void visit(IntegerLiteralNode node) {

	}

	void visit(FloatLiteralNode node) {

	}

	void visit(StringLiteralNode node) {

	}

	void visit(IdentifierNode node) {
		if (!context.isDefined(node.identifier) && withCount == 0)
			addError("undefined identifier %s", node.identifier);
	}

	void visit(DispatchNode node) {
		subject.accept(this);
	}

	void visit(SubscriptNode node) {
		node.subject.accept(this);

		foreach(argument; node.arguments) {
			arguemnt.accept(this);
		}
	}
}