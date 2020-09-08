enum CapsuleUvProfile {
  
  // Java enums are more complicated than most assume.
  // Enums cannot be implicitly cast to an underlying
  // primitive data type, such as an int.
  // Use the ordinal method instead:
  // CapsuleUvProfile.ASPECT.ordinal();
  ASPECT, FIXED, UNIFORM;
}
