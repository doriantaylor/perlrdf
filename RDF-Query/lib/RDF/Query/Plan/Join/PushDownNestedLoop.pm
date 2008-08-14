# RDF::Query::Plan::Join::PushDownNestedLoop
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Join::PushDownNestedLoop - Executable query plan for nested loop joins.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::Join::PushDownNestedLoop;

use strict;
use warnings;
use base qw(RDF::Query::Plan::Join);
use Scalar::Util qw(blessed);
use Data::Dumper;

BEGIN {
	$RDF::Query::Plan::Join::JOIN_CLASSES{ 'RDF::Query::Plan::Join::PushDownNestedLoop' }++;
}

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( $lhs, $rhs, $opt ) >>

=cut

sub new {
	my $class	= shift;
	my $lhs		= shift;
	my $rhs		= shift;
	my $opt		= shift || 0;
	unless ($opt) {
		throw RDF::Query::Error::MethodInvocationError -text => "PushDownNestedLoop join does not support non-optional joins due to bottom-up variable scoping rules (use NestedLoop instead)";
	}
	my $self	= $class->SUPER::new( $lhs, $rhs, $opt );
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "PushDownNestedLoop join plan can't be executed while already open";
	}
	
	$self->lhs->execute( $context );
	if ($self->lhs->state == $self->OPEN) {
		$self->[0]{context}			= $context;
		$self->[0]{outer}			= $self->lhs;
		$self->[0]{needs_new_outer}	= 1;
		$self->[0]{inner_count}		= 0;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
#	warn '########################################';
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open PushDownNestedLoop join";
	}
	my $outer	= $self->[0]{outer};
	my $inner	= $self->rhs;
	my $opt		= $self->[3];
	
	while (1) {
		if ($self->[0]{needs_new_outer}) {
			$self->[0]{outer_row}	= $outer->next;
			my $outer	= $self->[0]{outer_row};
			if (ref($outer)) {
				my $context	= $self->[0]{context};
				$self->[0]{needs_new_outer}	= 0;
				$self->[0]{inner_count}		= 0;
				if ($self->[0]{inner}) {
					$self->[0]{inner}->close();
				}
				my %bound	= %{ $context->bound };
				@bound{ keys %$outer }	= values %$outer;
				my $copy	= $context->copy( bound => \%bound );
#				warn "executing inner plan with bound: " . Dumper(\%bound);
				$self->[0]{inner}			= $inner->execute( $copy );
			} else {
				# we've exhausted the outer iterator. we're now done.
	#			warn "exhausted";
				return undef;
			}
		}
		
		while (my $inner_row = $self->[0]{inner}->next) {
#			warn "using inner row: " . Dumper($inner_row);
			if (my $joined = $inner_row->join( $self->[0]{outer_row} )) {
#				warn "-> joined\n";
				$self->[0]{inner_count}++;
				return $joined;
			} else {
				if ($opt) {
					return $self->[0]{outer_row};
				}
#				warn "-> didn't join\n";
			}
		}
		
		$self->[0]{needs_new_outer}	= 1;
		if ($self->[0]{inner}->state == $self->OPEN) {
			$self->[0]{inner}->close();
		}
		delete $self->[0]{inner};
		if ($opt and $self->[0]{inner_count} == 0) {
			return $self->[0]{outer_row};
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open PushDownNestedLoop join";
	}
	delete $self->[0]{inner};
	delete $self->[0]{outer};
	delete $self->[0]{needs_new_outer};
	delete $self->[0]{inner_count};
	$self->lhs->close();
	$self->SUPER::close();
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut