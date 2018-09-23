use Red::AST;
use Red::Column;
use Red::AST::Infix;
use Red::AST::Select;
use Red::AST::Unary;
use Red::AST::Value;
use Red::AST::Insert;
use Red::AST::Update;
use Red::AST::CreateTable;
use Red::Driver;
unit role Red::Driver::CommonSQL does Red::Driver;

proto method translate(Red::AST, $?) {*}

multi method translate(Red::AST::Select $_, $context?) {
    my $sel    = .of.^columns.keys.map({ "{.column.name} as {.column.attr-name}" }).join: ", ";
    my $tables = .tables.map({ .^table }).join: ", ";
    my $where  = self.translate: .filter, "select";
    "SELECT $sel FROM $tables WHERE $where", []
}

multi method translate(Red::AST::Infix $_, $context?) {
    "{ self.translate: .left, $context } { .op } { self.translate: .right, $context }"
}

multi method translate(Red::Column $_, $context?) {
    .name
}

multi method translate(Red::AST::Cast $_, $context?) {
    when Red::AST::Value {
        qq|'{ .value }'|
    }
    default {
        self.translate: .value, $context
    }
}

multi method translate(Red::AST::Value $_ where .type ~~ Str, $context?) {
    qq|'{ .value }'|
}

multi method translate(Red::AST::Value $_ where .type !~~ Str, $context?) {
    qq|{ .value }|
}

multi method translate(Red::Column $_, "create-table") {
    "{ .name } { self.default-type-for: .attr.type } { .nullable ?? "NULL" !! "NOT NULL" }{ " primary key" if .id }"
}

multi method translate(Red::AST::CreateTable $_, $context?) {
    "CREATE TABLE { .name }(\n{ .columns.map({ self.translate: $_, "create-table" }).join(",\n").indent: 3 }\n)", []
}

multi method translate(Red::AST::Insert $_, $context?) {
    my @values = .values.grep({ .value.value.defined });
    say @values;
    "INSERT INTO { .into }(\n{ @values>>.key.join(",\n").indent: 3 }\n)\nVALUES(\n{ @values>>.value.map(-> $val { self.translate: $val, "insert" }).join(",\n").indent: 3 }\n)", []
}

multi method translate(Red::AST::Update $_, $context?) {
    "UPDATE { .into } SET\n{ .values.kv.map(-> $col, $val { "{$col} = {self.translate: $val, "update"}" }).join(",\n").indent: 3 }\nWHERE { self.translate: .filter }", []
}

multi method default-type-for(Any --> "varchar(255)")   {}
multi method default-type-for(Str --> "varchar(255)")   {}
multi method default-type-for(Int --> "integer")        {}