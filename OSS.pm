# -*- cperl -*-

# Audio::OSS - Less DWIM, more useful than Audio::DSP
#
# Copyright (c) 2000 Cepstral LLC. All rights Reserved.
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# Written by David Huggins-Daines <dhd@cepstral.com>

package Audio::OSS;
use strict;

# Defines constants, which is why it needs to be done in BEGIN{}
# Also creates @EXPORT_OK, hence the push below
BEGIN {
    require Audio::OSS::Constants;
}

# We should generate these in Makefile.PL, but laziness says they're
# likely to stay the same for binary compatibility purposes...
use constant CINFO_TMPL => 'lll';
use constant BINFO_TMPL => 'llll';

use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
require Exporter;
@ISA = qw(Exporter);
push @EXPORT_OK, qw(dsp_sync dsp_reset dsp_get_caps
		    set_sps set_fmt set_fragment
		    get_fmt get_supported_fmts
		    get_outbuf_ptr get_inbuf_ptr
		    get_outbuf_info get_inbuf_info);
%EXPORT_TAGS = (
		funcs => [qw[
			     dsp_sync
			     dsp_reset
			     dsp_get_caps
			     set_sps
			     set_fmt
			     get_supported_fmts
			     set_fragment
			     get_outbuf_ptr
			     get_inbuf_ptr
			     get_outbuf_info
			     get_inbuf_info
			    ]],
		formats => [qw[
			       AFMT_QUERY
			       AFMT_S16_NE
			       AFMT_S16_LE
			       AFMT_S16_BE
			       AFMT_U16_LE
			       AFMT_U16_BE
			       AFMT_U8
			       AFMT_MU_LAW
			       AFMT_A_LAW
			      ]],
		caps => [qw[
			    DSP_CAP_REVISION
			    DSP_CAP_DUPLEX
			    DSP_CAP_REALTIME
			    DSP_CAP_BATCH
			    DSP_CAP_COPROC
			    DSP_CAP_TRIGGER
			    DSP_CAP_MMAP
			    DSP_CAP_MULTI
			    DSP_CAP_BIND
			   ]],
	       );

# We may have to 'filter' out constants that don't actually exist in
# @CONSTANTS here...  although the ones above should all be common

$VERSION=0.05;

sub dsp_reset {
    my $dsp = shift;

    ioctl $dsp, SNDCTL_DSP_SYNC, 0 or return undef;
    ioctl $dsp, SNDCTL_DSP_RESET, 0;
}

sub dsp_sync {
    my $dsp = shift;

    ioctl $dsp, SNDCTL_DSP_SYNC, 0;
}

sub dsp_get_caps {
    my $dsp = shift;
    my $caps = pack "L";
    ioctl $dsp, SNDCTL_DSP_GETCAPS, $caps or return undef;

    return $caps;
}

sub set_sps {
    my ($dsp, $sps) = @_;

    my $spd = pack "L", $sps;
    ioctl $dsp, SNDCTL_DSP_SPEED, $spd or return undef;
    return unpack "L", $spd;
}

sub set_fmt {
    my ($dsp, $fmt) = @_;

    my $sfmt = pack "L", $fmt;
    ioctl $dsp, SNDCTL_DSP_SETFMT, $sfmt or return undef;
    return unpack "L", $sfmt;
}

sub get_fmt {
    my $dsp = shift;

    my $sfmt = pack "L", AFMT_QUERY;
    ioctl $dsp, SNDCTL_DSP_SETFMT, $sfmt or return undef;
    return unpack "L", $sfmt;
}

sub get_supported_fmts {
    my $dsp = shift;

    my $fmts = pack "L";
    ioctl $dsp, SNDCTL_DSP_GETFMTS, $fmts or return undef;
    return unpack "L", $fmts;
}

sub set_fragment {
    my ($dsp, $shift, $max) = @_;

    # This is not really documented, but the code of the sound drivers
    # says that this is two halfwords packed together in host byte
    # order, the MSW being the shift (assuming this means size log 2),
    # the lower being the maximum number.  In general it seems that
    # shift must be 4 <= shift < 16, maxfrags must be >= 4.

    my $sfrag = pack "L", (($max << 16) | $shift);
    ioctl $dsp, SNDCTL_DSP_SETFRAGMENT, $sfrag;
}

sub get_outbuf_ptr {
    my $dsp = shift;
    my $cinfo = pack CINFO_TMPL;
    ioctl($dsp, SNDCTL_DSP_GETOPTR, $cinfo) or return undef;
    return unpack CINFO_TMPL, $cinfo;
}

sub get_inbuf_ptr {
    my $dsp = shift;
    my $cinfo = pack CINFO_TMPL;
    ioctl($dsp, SNDCTL_DSP_GETIPTR, $cinfo) or return undef;
    return unpack CINFO_TMPL, $cinfo;
}

sub get_outbuf_info {
    my $dsp = shift;
    my $binfo = pack BINFO_TMPL;
    ioctl($dsp, SNDCTL_DSP_GETOSPACE, $binfo) or return undef;
    return unpack BINFO_TMPL, $binfo;
}

sub get_inbuf_info {
    my $dsp = shift;
    my $binfo = pack BINFO_TMPL;
    ioctl($dsp, SNDCTL_DSP_GETISPACE, $binfo) or return undef;
    return unpack BINFO_TMPL, $binfo;
}

1;
__END__

=head1 NAME

Audio::OSS - pure-perl interface to OSS (open sound system) audio devices

=head1 SYNOPSIS

  use Audio::OSS qw(:funcs :formats);

  my $dsp = IO::Handle->new("</dev/dsp") or die "open failed: $!";
  dsp_reset($dsp) or die "reset failed: $!";

  my $mask = get_supported_formats($dsp);
  if ($mask & AFMT_S16_LE) {
    set_fmt($dsp, AFMT_S16_LE) or die set format failed: $!";
  }
  my $current_format = set_fmt($dsp, AFMT_QUERY);

  my $sps_actual = set_sps($dsp, 16000);

  set_fragment($dsp, $fragshift, $nfrags);
  my ($frags_avail, $frags_total, $fragsize, $bytes_avail)
      = get_outbuf_info($dsp);
  my ($bytes, $blocks, $dma_ptr) = get_outbuf_ptr($dsp);

=head1 DESCRIPTION

C<Audio::OSS> is a pure Perl interface to the Open Sound System, as
used on Linux, FreeBSD, and other Unix systems.

It provides a procedural interface based around filehandles opened on
the audio device (usually F</dev/dsp*> for PCM audio).

It also defines constants for various C<ioctl> calls and other things
based on the OSS system header files, so you don't have to rely on
C<.ph> files that may or may be correct or even present on your system.

Currently, only the PCM audio input and output functions are
supported.  Mixer support is likely in the future, sequencer support
less likely.

=head1 EXPORTS

The main exports of C<Audio::OSS> are rubber, tea, and tractor parts.

Seriously, though, nothing is exported by default.  However, there are
three export tags which cover the vast majority of things you might
conceivably want, and which exist on most systems.  These are:

=over 4

=item C<:funcs>

This tag imports the following functions, which perform various
operations on the PCM audio device:

  dsp_sync
  dsp_reset
  dsp_get_caps
  set_sps
  set_fmt
  get_supported_fmts
  set_fragment
  get_outbuf_ptr
  get_inbuf_ptr
  get_outbuf_info
  get_inbuf_info

=item C<:formats>

This tag imports the following constants, which correspond to
arguments to the C<set_fmt> and bits in the return value from
C<get_supported_fmts>:

  AFMT_QUERY
  AFMT_S16_NE
  AFMT_S16_LE
  AFMT_S16_BE
  AFMT_U16_LE
  AFMT_U16_BE
  AFMT_U8
  AFMT_MU_LAW
  AFMT_A_LAW

=item C<:caps>

This tag imports the following constants, which correspond to bits in
the return value from C<dsp_get_caps>:

  DSP_CAP_REVISION
  DSP_CAP_DUPLEX
  DSP_CAP_REALTIME
  DSP_CAP_BATCH
  DSP_CAP_COPROC
  DSP_CAP_TRIGGER
  DSP_CAP_MMAP
  DSP_CAP_MULTI
  DSP_CAP_BIND

=back

The full list of constants and functions which can be imported from
this module follows.  Note that not all of these may be available on
your system.  When you build this module, the C<Makefile.PL> will try
to find them all, leaving out any that fail.  To some extent, these
are documented in the system header files, specifically
F<E<lt>sys/soundcard.hE<gt>> or F<E<lt>linux/soundcard.hE<gt>>.

  SNDCTL_DSP_RESET
  SNDCTL_DSP_SYNC
  SNDCTL_DSP_SPEED
  SNDCTL_DSP_STEREO
  SNDCTL_DSP_GETBLKSIZE
  SNDCTL_DSP_SAMPLESIZE
  SNDCTL_DSP_CHANNELS
  SNDCTL_DSP_POST
  SNDCTL_DSP_SUBDIVIDE
  SNDCTL_DSP_SETFRAGMENT
  SNDCTL_DSP_GETOSPACE
  SNDCTL_DSP_GETISPACE
  SNDCTL_DSP_NONBLOCK
  SNDCTL_DSP_GETCAPS
  SNDCTL_DSP_GETFMTS
  SNDCTL_DSP_SETFMT
  SNDCTL_DSP_GETTRIGGER
  SNDCTL_DSP_SETTRIGGER
  SNDCTL_DSP_GETIPTR
  SNDCTL_DSP_GETOPTR
  SNDCTL_DSP_MAPINBUF
  SNDCTL_DSP_MAPOUTBUF
  SNDCTL_DSP_SETSYNCRO
  SNDCTL_DSP_SETDUPLEX
  SNDCTL_DSP_GETODELAY

  SNDCTL_DSP_GETCHANNELMASK
  SNDCTL_DSP_BIND_CHANNEL
  SNDCTL_DSP_PROFILE

  SOUND_PCM_READ_RATE
  SOUND_PCM_READ_CHANNELS
  SOUND_PCM_READ_BITS
  SOUND_PCM_READ_FILTER

  AFMT_QUERY
  AFMT_MU_LAW
  AFMT_A_LAW
  AFMT_IMA_ADPCM
  AFMT_U8
  AFMT_S16_LE
  AFMT_S16_BE
  AFMT_S16_NE
  AFMT_S8
  AFMT_U16_LE
  AFMT_U16_BE
  AFMT_MPEG
  AFMT_AC3

  DSP_CAP_REVISION
  DSP_CAP_DUPLEX
  DSP_CAP_REALTIME
  DSP_CAP_BATCH
  DSP_CAP_COPROC
  DSP_CAP_TRIGGER
  DSP_CAP_MMAP
  DSP_CAP_MULTI
  DSP_CAP_BIND

  PCM_ENABLE_INPUT
  PCM_ENABLE_OUTPUT

  DSP_BIND_QUERY
  DSP_BIND_FRONT
  DSP_BIND_SURR
  DSP_BIND_CENTER_LFE
  DSP_BIND_HANDSET
  DSP_BIND_MIC
  DSP_BIND_MODEM1
  DSP_BIND_MODEM2
  DSP_BIND_I2S
  DSP_BIND_SPDIF

  APF_NORMAL
  APF_NETWORK
  APF_CPUINTENS

=head1 BUGS

As mentioned above, the mixer interface is not supported.

The C<Makefile.PL> is pretty slow, and could be optimized to check
more than one constant at once, or all of them at once, even.

There is no object oriented interface (this is a feature, in my
opinion).

The documentation is lacking, but then, that's also true for OSS
itself.

=head1 AUTHOR

David Huggins-Daines <dhd@cepstral.com>

=head1 SEE ALSO

perl(1), F</usr/include/sys/soundcard.h>

=cut
