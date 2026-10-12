Name:           BerserkMC
Version:        1.4
Release:        4%{?dist}
Summary:        A local install wrapper for BerserkMC

License:        ASL 2.0
URL:            https://github.com/gagga1/BerserkMC
ExclusiveArch:  %{ix86} x86_64

BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib
Requires:       zenity %{?suse_version:lib}qt5-qtbase wget xrandr
Provides:       berserkmc = %{version}



%description
A local install wrapper for BerserkMC

%prep


%build

%install
mkdir -p %{buildroot}/opt/berserkmc
install -m 0644 ../ubuntu/berserkmc/opt/berserkmc/icon.svg %{buildroot}/opt/berserkmc/icon.svg
install -m 0755 ../ubuntu/berserkmc/opt/berserkmc/run.sh %{buildroot}/opt/berserkmc/run.sh
mkdir -p %{buildroot}/%{_datadir}/applications
desktop-file-install --dir=%{buildroot}%{_datadir}/applications ../ubuntu/berserkmc/usr/share/applications/berserkmc.desktop

mkdir -p %{buildroot}/%{_datadir}/metainfo
install -m 0644 ../ubuntu/berserkmc/usr/share/metainfo/berserkmc.metainfo.xml %{buildroot}/%{_metainfodir}/berserkmc.metainfo.xml
mkdir -p %{buildroot}/%{_mandir}/man1
install -m 0644 ../ubuntu/berserkmc/usr/share/man/man1/berserkmc.1 %{buildroot}/%{_mandir}/man1/berserkmc.1

%check
appstream-util validate-relax --nonet %{buildroot}/%{_metainfodir}/berserkmc.metainfo.xml

%files
%dir /opt/berserkmc
/opt/berserkmc/icon.svg
/opt/berserkmc/run.sh
%{_datadir}/applications/berserkmc.desktop
%{_metainfodir}/berserkmc.metainfo.xml
%dir %{_mandir}/man1
%{_mandir}/man1/berserkmc.1*

%changelog
* Mon Oct 12 2026 BerserkMC Contributors
- Rebrand package to BerserkMC (fork of MultiMC)

* Fri Jan 28 2022 Jan Drögehoff <sentrycraft123@gmail.com> - 1.4-4
- Update spec to support OpenSuse and conform to Fedora guidelines

* Sun Oct 03 2021 imperatorstorm <30777770+ImperatorStorm@users.noreply.github.com>
- added manpage

* Tue Jun 01 2021 kb1000 <fedora@kb1000.de> - 1.4-2
- Add xrandr to the dependencies

* Tue Dec 08 00:34:35 CET 2020 joshua-stone <joshua.gage.stone@gmail.com>
- Add metainfo.xml for improving package metadata

* Wed Nov 25 22:53:59 CET 2020 kb1000 <fedora@kb1000.de>
- Initial version of the RPM package, based on the Ubuntu package
