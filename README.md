WHAT IS IT
==========

Perversion (for Perl version) is a small distributed version control system (DVCS) written in Perl.
Around 2004 I read a lot of articles about DVCS. But Git did not yet exist and the only free alternatives (Gnu Arch and SVK) were somehow complicated to use.
On the other hand, I liked the idea that a DVCS could be written in a scripting language (Bash for Gnu Arch, Perl for SVK). So I wrote my own one in Perl.

I wrote it initially as a proof of concept, but finally I used it for some small projects betwen 2004 and 2007, until I finally had a real opportunity to learn using Git.
That said, I mostly used local depot (the one in the project itself) with manual backup, not sure the network/distributed part was completely mature.

I still sometimes use it for very small projects, as it keeps a feature occasionally useful: patches which are stored in .pver directory are zip archives in a human-readable format.

Recently I read about changeset-based DVCS, such as Darcs, and less known Pijul. 
I would not pretend that Perversion is compliant with patches theory, but by some aspects it looks closer to Pijul than to Git, which always stores snapshots
(Perversion stores snapshots only for first and last version: all other versions are stored as changesets)
In the future, if I find time, I would like to modify Perversion in the direction of a fully changeset-based DVCS, and see if I can make it compliant with patches theory.

In any case this code was not initially designed to be distributed wordwilde, once again it was a proof of concept for personal use; 
part of the code is in french and you may have other reasons why you find it not clean.

