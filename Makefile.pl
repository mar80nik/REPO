#!/usr/bin/perl

use Cwd;
use File::Find;

%Repos = (  'my_lib' => { 'dep' => []},
            'my_gsl' => { 'dep' => ['my_lib']},
            'TChart' => { 'dep' => ['my_lib']},
            'Refractometer' => { 'dep' => ['my_lib', 'my_gsl', 'TChart'], 
                                 'dlls' => ['cblas_Win32_Debug.dll','cblas_Win32_Release.dll',
                                     'cblas_x64_Debug.dll','cblas_x64_Release.dll',
                                     'gsl_Win32_Debug.dll', 'gsl_Win32_Release.dll',
                                     'gsl_x64_Debug.dll', 'gsl_x64_Release.dll', 
                                     'zlib1.dll','zlib1d.dll'] },
            'testWMF' => { 'dep' => ['my_lib'],
                           'dlls' => ['ijl15.dll','jpeg62.dll','libpng15d.dll','msvcr71d.dll','libdjvulibre.dll','libjpeg.dll',
                                      'i_view32.exe','pnmtodjvurle.exe','csepdjvu.exe',
                                      'zlib1.dll','zlib1d.dll'] },
            'DJVU_SEP' => {},
            'djvu' => { 'dep' => ['my_lib'],
                        'dlls' => ['djvudecode.exe','DjVuBundle.exe'] }
                        );
                           
$Repos{'Tracker'} = $Repos{'Refractometer'};
$Repos{'DJVU_SEP'} = $Repos{'testWMF'};
            
sub my_chdir
{
    my ($dir) = shift(@_);
    my ($cur_dir) = getcwd();
    chdir($dir);
    return $cur_dir;
}
         
sub MakeClone
{
    my ($repo_name) = shift(@_);
    my ($checkout) = shift(@_);
    print("=== Cloning: '$repo_name'\n");
    if(-d $repo_name)
    {
        print("===   Error: repo $repo_name already exists\n");        
    }
    else
    {
        `git clone https:\/\/github.com\/mar80nik\/$repo_name.git`;
        my $cur_dir = my_chdir($repo_name);
        `git remote set-url origin git\@github.com:mar80nik\/$repo_name.git`;
        chdir($cur_dir);
    }

    if ($checkout eq 'checkout')
    {
        print("=== Checking out LSV: ");
        my ($cur_dir) = my_chdir($repo_name);
        `git checkout LSV`;
        chdir($cur_dir);    
    }
}

sub CloneDep
{
    my ($repo_name) = shift(@_);    
    my ($arr) = ($Repos{$repo_name})->{dep};
    my (@dep) = @$arr;
    if ($#dep >= 0)
    {
        print("=== Cloning dependencies\n");
        MakeClone($_) foreach(@dep);
    }
}

sub LinkDLLs
{
    my ($repo_name) = shift(@_);
    my ($cur_dir) = getcwd();
    $cur_dir =~ s/\//\\/g;
    
    my @RepoDlls = @{$Repos{$repo_name}->{'dlls'}};
    @deps = @{$Repos{$repo_name}->{'dep'}};
    
    print("=== Creating symbolic links for $repo_name DLLs\n") if ($#RepoDlls >= 0);
    
    foreach $dll_name (@RepoDlls)
    {
        my $dll_name_dst = "$repo_name\\exe";
        $dll_name_src = '';
        
        find(\&FindCallback, ".");
        
        if ($dll_name_src eq '')
        {
            print("$dll_name not found\n");
            continue;
        }

        my $dst_dll = "$cur_dir\\$dll_name_dst\\$dll_name";
        my $src_dll = "$cur_dir\\$dll_name_src\\$dll_name";
        
        print("$src_dll => $dst_dll\n");
 
        `mkdir $dll_name_dst` unless(-d "$dll_name_dst");
        `del $dst_dll` if (-f "$dst_dll");
        `mklink $dst_dll $src_dll`;
    }
}

sub FindCallback()
{
    if (($_ eq $dll_name) && CheckFindPath())
    {
        $dll_name_src = $File::Find::dir;
        $dll_name_src =~ s/\//\\/g;
        $dll_name_src =~ s/\A\.\\//g;        
    }    
}

sub CheckFindPath()
{
    foreach $dep (@deps)
    {
        return TRUE if ($File::Find::dir =~ m/$dep/);
    }
    return 0;
}

sub CheckoutDep
{
    my ($repo_name) = shift(@_);      
    my ($cur_dir) = my_chdir($repo_name);
    if (-f 'Makefile.pl')
    {
        print("=== Checkouting dependencies\n");
        `Makefile.pl`;
    }
    else
    {
        print("No makefile\n");    
    }
    chdir($cur_dir);
}

### START ###
foreach(@ARGV)
{
    $target = $1 if ($_=~m/target=([\w+\-]+)/);
}

die("target should be defined\n") if $target eq '';

if (exists($Repos{$target}))
{    
    MakeClone($target, checkout);
    CloneDep($target);
    CheckoutDep($target);
    LinkDLLs($target);        
}
else
{
    print("===   Error: Target $target is not recgonized\n");
    print("===   It should be one of:\n");
    foreach(keys(%Repos))
    {
        print("$_\n");
    }    
}
