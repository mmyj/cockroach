#!/usr/bin/env perl
# Copyright 2017 Elasticsearch Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;

my $command = "mk_audit_arches.pl ". join(' ', @ARGV);

`curl -s -O https://raw.githubusercontent.com/linux-audit/audit-kernel/v4.7/include/uapi/linux/audit.h`;

open(GCC, "gcc -E -dD audit.h |") || die "can't run gcc";
my @arches;
while(<GCC>){
    if (/^#define (AUDIT_ARCH_\w+)/){
        my $arch = $1;
        push @arches, $1
    }
}
close GCC;

# Filter arches not known by compiler.
@arches = grep {! /(TILE|OPENRISC|ALPHA|MICROBLAZE)/} @arches;

my $outfile = 'defs_audit_arches.go';
open (FILE, "> $outfile") || die "problem opening $outfile\n";

print FILE <<EOF;
// $command
// MACHINE GENERATED BY THE ABOVE COMMAND; DO NOT EDIT

// Copyright 2017 Elasticsearch Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// +build ignore

package auparse

/*
#include <audit.h>
*/
import "C"

import "fmt"

// auditArch represents a machine architecture (i.e. arm, ppc, x86_64).
type auditArch uint32

// List of architectures constants used by then kernel.
const(
EOF

foreach my $arch (sort @arches) {
    print FILE "\t$arch auditArch = C.$arch\n";
}

print FILE <<EOF;
)

var auditArchNames = map[auditArch]string{
EOF

foreach my $arch (sort @arches) {
    if ($arch =~ m/^AUDIT_ARCH_(\w+)/) {
        my $name = lc($1);
        print FILE "\t$arch: \"$name\",\n";
    }
}

print FILE <<EOF;
}

func (a auditArch) String() string {
    name, found := auditArchNames[a]
    if found {
        return name
    }

    return fmt.Sprintf("unknown[%x]", uint32(a))
}
EOF

close(FILE);

`go tool cgo -godefs $outfile > zaudit_arches.go`;
`gofmt -w $outfile zaudit_arches.go`;
