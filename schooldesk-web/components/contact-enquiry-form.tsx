"use client";

import { FormEvent, useState } from "react";

export function ContactEnquiryForm() {
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState("sending");
    try {
      const response = await fetch("/api/admission-inquiries", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(Object.fromEntries(new FormData(event.currentTarget))),
      });
      setState(response.ok ? "sent" : "error");
      if (response.ok) event.currentTarget.reset();
    } catch { setState("error"); }
  }
  if (state === "sent") return <div className="contact-form-success"><b>Thank you.</b><p>Our admissions team will contact you shortly.</p></div>;
  return <form className="contact-enquiry-form" onSubmit={submit}>
    <label>Parent name<input name="name" required placeholder="Your name" /></label>
    <label>Phone number<input name="phone" required inputMode="tel" placeholder="Your number" /></label>
    <label>Email address<input name="email" required type="email" placeholder="you@example.com" /></label>
    <label>Child’s name<input name="child_name" placeholder="Child’s name" /></label>
    <label>Child’s age<select name="child_age" required defaultValue=""><option value="" disabled>Select age</option><option>1.5–6 years</option><option>2–3 years</option><option>3–4 years</option><option>4–5 years</option><option>5–6 years</option></select></label>
    <label>Program of interest<select name="program" required defaultValue=""><option value="" disabled>Select program</option><option>Daycare</option><option>Playgroup</option><option>Nursery</option><option>PP1</option><option>PP2</option></select></label>
    <label className="contact-form-message">How can we help?<textarea name="message" rows={4} placeholder="Tell us about your child or preferred visit time" /></label>
    {state === "error" && <p className="contact-form-error">We could not send your enquiry. Please try again.</p>}
    <input type="hidden" name="source" value="contact" />
    <button className="primary-button" disabled={state === "sending"}>{state === "sending" ? "Sending…" : "Send enquiry →"}</button>
  </form>;
}
