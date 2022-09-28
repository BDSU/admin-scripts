Damit die Benutzer aus dem neuen Tenant auch weiterhin auf den BDSU-SharePoint zugreifen können und mit anderen JEs in Microsoft Teams zusammenarbeiten, müssen sie als Gast-Benutzer im BDSU-Tenant angelegt werden. Damit das auch zukünftig automatisch geschen kann und die Benutzer auch nicht erst manuell eine Einladungsmail bestätigen müssen, muss ein Benutzer aus dem BDSU-Tenant als Gast zum JE-Tenant hinzugefügt werden. Aus vorgegebenen Gruppen kann dieser Account dann alle aktiven Mitglieder auslesen und als neue Gast-Benutzer in den BDSU-Tenant synchronisieren.

# Sync-Admin zum eigenen Tenant einladen

- Der JE-Admin muss hierfür zuerst den Account <span>sync-admin</span>@bdsu-connect.de als Gast-Benutzer zum eigenen Tenant einladen
- Dies geht in der [Benutzerübersicht im Azure Active Directory](https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/UsersManagementMenuBlade/AllUsers)

![Bild: Neuen Gastbenutzer hinzufügen](assets/gastbenutzer1.png?raw=true)
![Bild: BDSU Sync Account einladen](assets/gastbenutzer2.png?raw=true)

- Der Sync-Admin erhält dadurch eine Einladungsmail, die der BDSU-Admin öffnen muss, um die Einladung abzuschließen

# Gruppen auswählen/erstellen

- Für die Synchronisation wird eine oder mehrere Gruppe/n benötigt, in denen alle Mitglieder **direkt** enthalten sind, die automatisch synchronisiert werden sollen => es können keine Verschachtelungen automatisch aufgelöst werden
- Geeignet sind Gruppen wie <span>mitglieder</span>@jedomain.de, <span>anwaerter</span>@jedomain.de, <span>alle</span>@jedomain.de o.ä.


# Gruppen-IDs raussuchen

- Von den ausgewählten Gruppen müssen Name und Object-ID an den BDSU-Admin mitgeteilt werden
- Diese findet man in [Azure Active Directory beim Gruppen-Objekt](https://aad.portal.azure.com/#blade/Microsoft_AAD_IAM/GroupsManagementMenuBlade/AllGroups):

![Bild: ObjectId in Azure AD herausfinden](assets/objectId.png?raw=true)

# Sync durchführen (BDSU-Admin)

- Der BDSU-Admin kann nun die Gruppen-IDs in das Sync-Skript eintragen und damit alle Benutzer aus den Gruppen automatisch als Gast in den BDSU einladen
- Die Benutzer können anschließend mit ihrem neuen Office365-Account auch direkt auf den [BDSU-SharePoint](https://bdsuev.sharepoint.com/) zugreifen. Beim ersten Login müssen sie dafür den Zugriff freigeben
- Die Gast-Benutzer können auch auf den SharePoint-Bereich der JE im BDSU-Tenant berechtigt werden


# BDSU-Verteiler einrichten (JE-Admin/BDSU-Admin)

- Es muss sichergestellt sein, dass [alle verpflichtenden E-Mail-Verteiler für den BDSU](https://bdsuev.sharepoint.com/SitePages/%C3%9Cbersichtsseiten/Leitf%C3%A4den/E-Mail-Verteiler.aspx) bei der JE eingerichtet und funktionsfähig sind
- Wenn diese Verteiler eingerichtet sind, muss der BDSU-Admin diese als Kontakte im BDSU-Tenant hinzufügen (11_BDSU-create_distribution_contacts.ps1) und in die Verteiler mit eintragen
