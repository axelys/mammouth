import "../basic/option.dart" show Option;
import "../diagnostic/diagnosticEngine.dart" show DiagnosticEngine;
import "../ast/ast.dart" as ast;
import "./token.dart" show TokenKind, Token;
import "./precedence.dart" show Precedence;

class Parser {
    Token _current;

    DiagnosticEngine _diagnosticEngine;

    Parser(this._diagnosticEngine);

    void setInput(List<Token> input) {
        this._current = input.first;
    }

    /**
     *      Document := [Inline | Script]* EOS
     */
    Option<ast.Document> parseDocument({bool reportError = true}) {
        List<ast.DocumentEntity> elements = <ast.DocumentEntity>[];
        while(this._current != null) {
            if(this._current.kind.kindOf(TokenKind.INLINE)) {
                Option<ast.Inline> result = this.parseInline();
                if(result.isNone()) {
                    // TODO:: error already reported
                    if(reportError) {
                        // TODO: report error
                    }
                    return new Option<ast.Document>();
                }
                elements.add(result.some);
            } else if(this._current.kind.kindOf(TokenKind.STARTTAG)) {
                Option<ast.Script> result = this.parseScript();
                if(result.isNone()) {
                    if(reportError) {
                        // TODO: report error
                    }
                    return new Option<ast.Document>();
                }
                elements.add(result.some);
            } else if(this._current.kind.kindOf(TokenKind.EOS)) {
                this._current = this._current.next;
                continue;
            } else {
                if(reportError) {
                    // TODO: report error
                }
            }
        }
        return new Option()..some = new ast.Document(elements);
    }

    /**
     *      Inline := INLINE
     */
    Option<ast.Inline> parseInline({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.INLINE)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Inline>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.Inline>()..some = new ast.Inline(token);
    }

    /**
     *      Script := STARTTAG Block ENDTAG
     */
    Option<ast.Script> parseScript({bool reportError = true}) {
        ast.Block block;
        Token startTag, endTag;
        if(!this._current.kind.kindOf(TokenKind.STARTTAG)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Script>();
        }
        startTag = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        Option<ast.Block> result = this.parseBlock();
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Script>();
        }
        block = result.some;
        if(!this._current.kind.kindOf(TokenKind.ENDTAG)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Script>();
        }
        endTag = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.Script>()..some = new ast.Script(startTag, block, endTag);
    }

    /**
     *      Block := INDENT Statement [MIDENT Statement]*  OUTDENT
     */
    Option<ast.Block> parseBlock({bool reportError = true}) {
        Token indentToken, outdentToken;
        List<ast.Statement> statements = new List<ast.Statement>();
        if(!this._current.kind.kindOf(TokenKind.INDENT)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Block>();
        }
        indentToken = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        while(this._current != null && !this._current.kind.kindOf(TokenKind.OUTDENT)) {
            Option<ast.Statement> result = this.parseStatement();
            if(result.isNone()) {
                // TODO: throw an error
                return new Option<ast.Block>();
            }
            statements.add(result.some);
            if(!this._current.kind.kindOf(TokenKind.OUTDENT)) {
                if(!this._current.kind.kindOf(TokenKind.MIDENT)) {
                    if(reportError) {
                        // TODO: report error
                    }
                    return new Option<ast.Block>();
                }
                // MARK(MOVE TOKEN)
                this._current = this._current.next;
            }
        }
        if(!this._current.kind.kindOf(TokenKind.OUTDENT)) {
            // TODO: throw an error
            return new Option<ast.Block>();
        }
        outdentToken = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.Block>()..some = new ast.Block(indentToken, statements, outdentToken);
    }

    /**
     *      Statement := VariableDeclarationOrExpressionStatement
     */
    Option<ast.Statement> parseStatement() {
        return this.parseVariableDeclarationOrExpressionStatement();
    }

    /**
     *      VariableDeclarationOrExpressionStatement := VariableDeclarationStatement
     *                                                | ExpressionStatement
     */
    Option<ast.Statement> parseVariableDeclarationOrExpressionStatement() {
        Token startToken = this._current;

        // first, we try to parse a type, without reporting error
        Option<ast.TypeAnnotation> typeResult = this.parseTypeName(reportError: false); // TODO: to parseTypeAnnotation
        if(typeResult.isSome()) {
            ast.TypeAnnotation type = typeResult.some;

            // if a type is parsed, we try to parse a name, without reporting error
            Option<ast.SimpleIdentifier> nameResult = this.parseSimpleIdentifier(reportError: false);
            if(nameResult.isSome()) {
                return this.parseVariableDeclarationStatement(type, nameResult.some);
            }
        }

        // MARK(MAKE NODE)
        this._current = startToken;
        // TODO: report manage error
        return this.parseExpressionStatement();
    }

    /**
     *      VariableDeclarationStatement := TypeAnnotation SimpleIdentifier [EQUALASSIGN Expression]
     */
    Option<ast.VariableDeclarationStatement> parseVariableDeclarationStatement(ast.TypeAnnotation type, ast.SimpleIdentifier name, {bool reportError = true}) {
        if(this._current != null && this._current.kind.kindOf(TokenKind.EQUALASSIGN)) {
            Token equal = this._current;
            // MARK(MOVE TOKEN)
            this._current = this._current.next;
            Option<ast.Expression> expressionResult = this.parseExpression();
            if(expressionResult.isNone()) {
                if(reportError) {
                // TODO: report error
            }
                return new Option<ast.VariableDeclarationStatement>();
            }
            return new Option<ast.VariableDeclarationStatement>()..some = new ast.VariableDeclarationStatement(type, name, equal, expressionResult.some);
        }
        return new Option<ast.VariableDeclarationStatement>()..some = new ast.VariableDeclarationStatement(type, name); 
    }

    /**
     *      ExpressionStatement := Expression
     */
    Option<ast.ExpressionStatement> parseExpressionStatement({bool reportError = true}) {
        Option<ast.Expression> result = this.parseExpression();
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.ExpressionStatement>();
        }
        // MARK(MAKE NODE)
        return new Option<ast.ExpressionStatement>()..some = new ast.ExpressionStatement(result.some);
    }

    /**
     *      TypeName := SimpleIdentifier
     */
    Option<ast.TypeName> parseTypeName({bool reportError = true}) {
        Option<ast.SimpleIdentifier> result = this.parseSimpleIdentifier(reportError: reportError);
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.TypeName>();
        }
        // MARK(MAKE NODE)
        return new Option<ast.TypeName>()..some = new ast.TypeName(result.some);
    }

    /**
     *      Expression := SimpleIdentifier
     *                  | Literal
     */
    Option<ast.Expression> parseExpression({bool reportError = true}) {
        return this.parseAssignmentExpression(reportError: reportError);
    }

    /**
     *      AssignmentExpression := SimpleIdentifier ASSIGN Expression
     */
    Option<ast.Expression> parseAssignmentExpression({bool reportError = true}) {
        ast.Expression left, right;
        Option<ast.Expression> result = this.parseBinaryExpression(reportError: reportError);
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Expression>();
        }
        left = result.some;
        if(!this.isAssignementOperator()) {
            return result;
        }
        Option<ast.AssignmentOperator> operat0r = this.parseAssignementOperator();
        result = this.parseExpression(reportError: reportError); // TODO: to parseBinaryExpression
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Expression>();
        }
        right = result.some;
        // MARK(MAKE NODE)
        return new Option<ast.Expression>()..some = new ast.AssignmentExpression(left, operat0r.some, right);
    }

    /**
     *      BinaryExpression := PrefixExpression BINARY Expression
     */
    Option<ast.Expression> parseBinaryExpression({Precedence minPrecedence = Precedence.Zero, bool reportError = true}) {
        ast.Expression node;
        Option<ast.Expression> result = this.parsePrefixExpression(reportError: reportError);
        if(result.isNone()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.Expression>();
        }
        node = result.some;
        // TODO: test precedence
        while(this._current.kind.kindOf(TokenKind.BINARY) && this._current.precedence >= minPrecedence) {
            Option<ast.BinaryOperator> operat0rResult = this.parseBinaryOperator(reportError: reportError);
            if(operat0rResult.isNone()) {
                if(reportError) {
                    // TODO: report error
                }
                return new Option<ast.Expression>();
            }
            ast.BinaryOperator operat0r = operat0rResult.some;
            result = this.parseBinaryExpression(minPrecedence: operat0rResult.some.precedence + 1);
            if(result.isNone()) {
                if(reportError) {
                    // TODO: report error 
                }
                return new Option<ast.Expression>();
            }
            // MARK(MAKE NODE)
            node = new ast.BinaryExpression(node, operat0r, result.some);
        }
        return new Option<ast.Expression>()..some = node;
    }

    Option<ast.Expression> parsePrefixExpression({bool reportError = true}) {
        ast.Expression node;
        if(this.isUpdateOperator()) {
            Option<ast.UpdateOperator> operat0rResult = this.parseUpdateOperator(reportError: reportError);
            if(operat0rResult.isNone()) {
                if(reportError) {
                    // TODO: report error
                }
                return new Option<ast.Expression>();
            }
            Option<ast.Expression> result = this.parsePrefixExpression(reportError: reportError);
            if(result.isNone()) {
                if(reportError) {
                    // TODO: report error 
                }
                return new Option<ast.Expression>();
            }
            // MARK(MAKE NODE)
            return new Option<ast.Expression>()..some = new ast.UpdateExpression(result.some, operat0rResult.some, true);
        }
        return this.parsePrimaryExpression(reportError: reportError);
    }

    /**
     *      PrimaryExpression := SimpleIdentifier
     *                         | Literal
     */
    Option<ast.Expression> parsePrimaryExpression({bool reportError = true}) {
        if(this._current.kind.kindOf(TokenKind.NAME)) {
            return this.parseSimpleIdentifier(reportError: reportError);
        }
        return this.parseLiteral();
    }

    /**
     *      SimpleIdentifier := NAME
     */
    Option<ast.SimpleIdentifier> parseSimpleIdentifier({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.NAME)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.SimpleIdentifier>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.SimpleIdentifier>()..some = new ast.SimpleIdentifier(token);
    }

    /**
     *      Literal := BooleanLiteral
     *               | StringLiteral
     *               | IntegerLiteral
     *               | FloatLiteral
     */
    Option<ast.Literal> parseLiteral({bool reportError = true}) {
        if(this._current.kind.kindOf(TokenKind.BOOLEAN)) {
            return this.parseBooleanLiteral(reportError: reportError);
        } else if(this._current.kind.kindOf(TokenKind.STRING)) {
            return this.parseStringLiteral(reportError: reportError);
        } else if(this._current.kind.kindOf(TokenKind.INTEGER)) {
            return this.parseIntegerLiteral(reportError: reportError);
        } else if(this._current.kind.kindOf(TokenKind.FLOAT)) {
            return this.parseFloatLiteral(reportError: reportError);
        }
        // TODO: report error
        return new Option<ast.Literal>();
    }

    /**
     *      BooleanLiteral := BOOLEAN
     */
    Option<ast.BooleanLiteral> parseBooleanLiteral({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.BOOLEAN)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.BooleanLiteral>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.BooleanLiteral>()..some = new ast.BooleanLiteral(token);
    }

    /**
     *      StringLiteral := STRING
     */
    Option<ast.StringLiteral> parseStringLiteral({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.STRING)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.StringLiteral>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.StringLiteral>()..some = new ast.StringLiteral(token);
    }

    /**
     *      IntegerLiteral := INTEGER
     */
    Option<ast.IntegerLiteral> parseIntegerLiteral({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.INTEGER)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.IntegerLiteral>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.IntegerLiteral>()..some = new ast.IntegerLiteral(token);
    }

    /**
     *      FloatLiteral := FLOAT
     */
    Option<ast.FloatLiteral> parseFloatLiteral({bool reportError = true}) {
        Token token;
        if(!this._current.kind.kindOf(TokenKind.FLOAT)) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.FloatLiteral>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.FloatLiteral>()..some = new ast.FloatLiteral(token);
    }

    //*-- Operators

    bool isAssignementOperator() {
        if(this._current != null && this._current.kind.kindOf(TokenKind.ASSIGN)) {
            return true;
        }
        return false;
    }

    bool isBinaryOperator() {
        if(this._current != null && this._current.kind.kindOf(TokenKind.BINARY)) {
            return true;
        }
        return false;
    }

    bool isUpdateOperator() {
        if(this._current != null && this._current.kind.kindOf(TokenKind.UPDATE)) {
            return true;
        }
        return false;
    }

    Option<ast.AssignmentOperator> parseAssignementOperator({bool reportError = true}) {
        Token token;
        if(!this.isAssignementOperator()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.AssignmentOperator>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.AssignmentOperator>()..some = new ast.AssignmentOperator(token);
    }

    Option<ast.BinaryOperator> parseBinaryOperator({bool reportError = true}) {
        Token token;
        if(!this.isBinaryOperator()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.BinaryOperator>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.BinaryOperator>()..some = new ast.BinaryOperator(token);
    }

    Option<ast.UpdateOperator> parseUpdateOperator({bool reportError = true}) {
        Token token;
        if(!this.isUpdateOperator()) {
            if(reportError) {
                // TODO: report error
            }
            return new Option<ast.UpdateOperator>();
        }
        token = this._current;
        // MARK(MOVE TOKEN)
        this._current = this._current.next;
        // MARK(MAKE NODE)
        return new Option<ast.UpdateOperator>()..some = new ast.UpdateOperator(token);
    }
}