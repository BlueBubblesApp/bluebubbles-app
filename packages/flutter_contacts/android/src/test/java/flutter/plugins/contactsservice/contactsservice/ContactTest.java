package flutter.plugins.contactsservice.contactsservice;

import static com.google.common.truth.Truth.assertThat;

import org.junit.Test;

public class ContactTest {

  @Test
  public void compareTo_nullParam() {
    Contact contact1 = new Contact("id");
    contact1.givenName = "givenName";

    Contact contact2 = new Contact("id2");

    assertThat(contact1.compareTo(contact2))
        .isGreaterThan(0);
  }

  @Test
  public void compareTo_largerParam() {
    Contact contact1 = new Contact("id");
    contact1.givenName = "a";

    Contact contact2 = new Contact("id2");
    contact2.givenName = "b";

    assertThat(contact1.compareTo(contact2))
        .isLessThan(0);
  }

  @Test
  public void compareTo_smallerParam() {
    Contact contact1 = new Contact("id");
    contact1.givenName = "b";

    Contact contact2 = new Contact("id2");
    contact2.givenName = "a";

    assertThat(contact1.compareTo(contact2))
        .isGreaterThan(0);
  }

  @Test
  public void compareTo_givenNameNull() {
    Contact contact1 = new Contact("id");
    contact1.givenName = null;

    Contact contact2 = new Contact("id2");
    contact2.givenName = null;

    assertThat(contact1.compareTo(contact2))
        .isEqualTo(0);
  }

  @Test
  public void compareTo_currentContactGivenNameNull() {
    Contact contact1 = new Contact("id");
    contact1.givenName = null;

    Contact contact2 = new Contact("id2");
    contact2.givenName = "b";

    assertThat(contact1.compareTo(contact2))
        .isLessThan(0);
  }

  @Test
  public void compareTo_nullContact() {
    Contact contact1 = new Contact("id");
    contact1.givenName = "a";

    assertThat(contact1.compareTo(null))
        .isGreaterThan(0);
  }

  @Test
  public void compareTo_transitiveCompare() {
    Contact contact1 = new Contact("id");
    contact1.givenName = "b";

    Contact contact2 = new Contact("id2");
    contact2.givenName = "a";

    Contact contact3 = new Contact("id3");
    contact3.givenName = null;

    // b > a
    assertThat(contact1.compareTo(contact2))
        .isGreaterThan(0);

    // a > null
    assertThat(contact2.compareTo(contact3))
        .isGreaterThan(0);

    // This implies => b > null
    assertThat(contact1.compareTo(contact3))
        .isGreaterThan(0);
  }
}