package Mo::xxx;my$M="Mo::";
$VERSION='0.11';
use constant XXX_skip=>1;${$M.'::DumpModule'}='YAML::XS';*{$M.'xxx::e'}=sub{my($P,$e)=@_;$e->{WWW}=sub{require XXX;local$XXX::DumpModule=${$M.DumpModule};XXX::WWW(@_)};$e->{XXX}=sub{require XXX;local$XXX::DumpModule=${$M.DumpModule};XXX::XXX(@_)};$e->{YYY}=sub{require XXX;local$XXX::DumpModule=${$M.DumpModule};XXX::YYY(@_)};$e->{ZZZ}=sub{require XXX;local$XXX::DumpModule=${$M.DumpModule};XXX::ZZZ(@_)}};
