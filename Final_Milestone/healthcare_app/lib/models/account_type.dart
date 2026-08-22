enum AccountType {
  patient('User / Patient'),
  doctor('Doctor');

  const AccountType(this.label);
  ///Text shown under the icon on the selection card.
  final String label;
}
