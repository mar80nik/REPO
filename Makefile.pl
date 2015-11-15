use Cwd;

%Repos = (  'my_lib' => { 'dep' => []},
            'my_gsl' => { 'dep' => ['my_lib']},
            'TChart' => { 'dep' => ['my_lib']},
            'Refractometer' => { 'dep' => ['my_lib', 'my_gsl', 'TChart'] }  );
            
%DLLs = ('my_gsl\\dll\\'        =>  ['cblas_Win32_Debug.dll','cblas_Win32_Release.dll',
                                     'cblas_x64_Debug.dll','cblas_x64_Release.dll',
                                     'gsl_Win32_Debug.dll', 'gsl_Win32_Release.dll',
                                     'gsl_x64_Debug.dll', 'gsl_x64_Release.dll'],
        'my_lib\\zlib\\dll\\'   =>  ['zlib1.dll'] );

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
    print("=== Creating symbolic links for my_gsl DLLs\n");
    `mkdir $repo_name\\exe` unless(-d "$repo_name\\exe");
    
    foreach $path (keys(%DLLs))
    {
        print("path = $path\n");
        foreach $dll (@{$DLLs{$path}})
        {
            print("dll = $dll\n");
            `del $repo_name\\exe\\$dll` if (-f "$repo_name\\exe\\$dll");
            `mklink $cur_dir\\$repo_name\\exe\\$dll $cur_dir\\$path$dll`;
        }
    }
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
    if ($target eq 'Refractometer')
    {        
        LinkDLLs($target);        
    }
}
else
{
    print("===   Error: Target $target is not recgonized\n");
}
