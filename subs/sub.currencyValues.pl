$chaos{"Blessed Orb"} = 3 / 4;
$chaos{"Cartographers Chisel"} =  1 / 3;
$chaos{"Chaos Orb"} = 1;
$chaos{"Chromatic Orb"} =  1 / 15;
$chaos{"Divine Orb"} = 17;
$chaos{"Eternal Orb"} = 50;
$chaos{"Exalted Orb"} = 40;
$chaos{"Gemcutters Prism"} = 2;
$chaos{"Jewellers Orb"} = 1 / 8;
$chaos{"Mirror of Kalandra"} = 100;
$chaos{"Orb of Alchemy"} = 1 / 2;
$chaos{"Orb of Alteration"} = 1 / 16;
$chaos{"Orb of Chance"} = 1 / 7;
$chaos{"Orb of Change"} = 1 / 7 ;
$chaos{"Orb of Fusing"} = 1 / 2;
$chaos{"Orb of Regret"} = 1;
$chaos{"Orb of Scouring"} =  1 / 2;
$chaos{"Portal Scroll"} = 1 / 160;
$chaos{"Regal Orb"} = 2;
$chaos{"Scroll of Wisdom"} = 1 / 160; 
$chaos{"Vaal Orb"} = 1;

sub StandardizeCurrency {
  my $target = $_[0];
  my $type = $_[1];
  # Hash of values to standardize to chaos

  my $value = $target * $chaos{$type};
  return($value);
}

sub niceCEV {
  my $target = $_[0];

  if ($target < $chaos{"Exalted Orb"}) {
    $value = sprintf("%.2f", $target);
    $value =~ s/\.00//g;
    return("$value Chaos");
  } else {
    my $value = $target / $chaos{"Exalted Orb"};
    $value = sprintf("%.2f", $value);
    $value =~ s/\.00//g;
    return("$value Ex");
  }


}

return true;
