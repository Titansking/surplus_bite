// Emulator-backed checks for backend/firebase/firestore.rules.
//   npm run test:rules
//
// These assert the security properties the rules are supposed to guarantee:
// anonymous access is denied, roles cannot escalate, listings cannot be
// transferred or zeroed out by a buyer, orders walk a fixed lifecycle, and a
// buyer cannot write someone else's rating.

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  addDoc,
  serverTimestamp,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const PROVIDER = 'provider-1';
const PROVIDER2 = 'provider-2';
const CONSUMER = 'consumer-1';
const ATTACKER = 'attacker-1';

let passed = 0;
const failures = [];

async function it(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok   ${name}`);
  } catch (e) {
    failures.push({ name, error: e });
    console.log(`  FAIL ${name}\n       ${e.message}`);
  }
}

function newUserDoc(over = {}) {
  return {
    name: 'Test User',
    email: 'user@example.com',
    phone: '',
    role: 'consumer',
    profileImage: null,
    businessName: null,
    businessDescription: null,
    location: null,
    address: null,
    rating: 0,
    totalRatings: 0,
    favorites: [],
    createdAt: new Date(),
    updatedAt: new Date(),
    ...over,
  };
}

function newListingDoc(over = {}) {
  return {
    providerId: PROVIDER,
    providerName: 'Sunrise Bakery',
    providerPhone: '9999999999',
    title: 'Surplus bread',
    description: 'Freshly baked bread left over from today',
    category: 'Bakery',
    originalPrice: 100,
    discountedPrice: 40,
    quantity: 10,
    unit: 'pieces',
    images: ['https://example.com/a.jpg'],
    location: null,
    address: null,
    pickupLocation: 'Front desk',
    dietaryTags: ['Vegan'],
    pickupStart: new Date(),
    pickupEnd: new Date(Date.now() + 86_400_000),
    expiryDate: new Date(Date.now() + 172_800_000),
    status: 'available',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...over,
  };
}

function newReviewDoc(over = {}) {
  return {
    orderId: '',
    reviewerId: '',
    reviewerName: 'Consumer',
    revieweeId: PROVIDER,
    rating: 5,
    comment: 'Great, saved my lunch',
    createdAt: new Date(),
    ...over,
  };
}

function newOrderDoc(over = {}) {
  return {
    listingId: 'listing-1',
    listingTitle: 'Surplus bread',
    buyerId: CONSUMER,
    buyerName: 'Consumer One',
    providerId: PROVIDER,
    providerName: 'Sunrise Bakery',
    providerPhone: '9999999999',
    pickupLocation: 'Front desk',
    quantity: 2,
    totalPrice: 80,
    status: 'pending',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...over,
  };
}

const testEnv = await initializeTestEnvironment({
  projectId: 'surplus-bite-local',
  firestore: {
    rules: readFileSync('firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const anon = () => testEnv.unauthenticatedContext().firestore();
const asProvider = () => testEnv.authenticatedContext(PROVIDER).firestore();
const asProvider2 = () => testEnv.authenticatedContext(PROVIDER2).firestore();
const asConsumer = () => testEnv.authenticatedContext(CONSUMER).firestore();
const asAttacker = () => testEnv.authenticatedContext(ATTACKER).firestore();

// Rules bypass: seeds fixtures without auth.
const seed = (path, data) =>
  testEnv.withSecurityRulesDisabled(async (ctx) =>
    ctx.firestore().doc(path).set(data),
  );

async function reset() {
  await testEnv.clearFirestore();
  await seed(`users/${PROVIDER}`, newUserDoc({ role: 'provider' }));
  await seed(`users/${PROVIDER2}`, newUserDoc({ role: 'provider' }));
  await seed(`users/${CONSUMER}`, newUserDoc({ role: 'consumer' }));
  await seed(`users/${ATTACKER}`, newUserDoc({ role: 'consumer' }));
  await seed('listings/listing-1', newListingDoc());
}

// ---------------------------------------------------------------- users

console.log('\nusers');

await it('anonymous read is denied', async () => {
  await reset();
  await assertFails(getDoc(doc(anon(), 'users', CONSUMER)));
});

await it('a user can read their own profile', async () => {
  await reset();
  await assertSucceeds(getDoc(doc(asConsumer(), 'users', CONSUMER)));
});

await it('a user cannot read someone else\'s profile', async () => {
  await reset();
  await assertFails(getDoc(doc(asConsumer(), 'users', PROVIDER)));
});

const NEWCOMER = 'newcomer-1';
const asNewcomer = () => testEnv.authenticatedContext(NEWCOMER).firestore();

await it('self-registration is allowed with a zeroed rating', async () => {
  await reset();
  await assertSucceeds(
    setDoc(doc(asNewcomer(), 'users', NEWCOMER), newUserDoc()),
  );
});

await it('registration cannot seed a non-zero rating', async () => {
  await reset();
  await assertFails(
    setDoc(
      doc(asNewcomer(), 'users', NEWCOMER),
      newUserDoc({ rating: 5, totalRatings: 99 }),
    ),
  );
});

await it('registration cannot pick an unknown role', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asNewcomer(), 'users', NEWCOMER), newUserDoc({ role: 'admin' })),
  );
});

await it('a user cannot change their own role', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'users', CONSUMER), {
      role: 'provider',
      updatedAt: new Date(),
    }),
  );
});

await it('a user cannot escalate to provider via self-update', async () => {
  await reset();
  // Even bundled with otherwise-allowed fields the role change must be denied.
  await assertFails(
    updateDoc(doc(asConsumer(), 'users', CONSUMER), {
      role: 'provider',
      name: 'Still Me',
      updatedAt: new Date(),
    }),
  );
});

await it('a consumer cannot become a provider', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'users', CONSUMER), {
      role: 'provider',
      updatedAt: new Date(),
    }),
  );
});

await it('a user can update their own editable fields', async () => {
  await reset();
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'users', CONSUMER), {
      name: 'New Name',
      phone: '9000000000',
      updatedAt: new Date(),
    }),
  );
});

await it('a user cannot rewrite their own aggregate rating', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'users', CONSUMER), {
      rating: 5,
      updatedAt: new Date(),
    }),
  );
});

await it('an attacker cannot set another user\'s rating without a review', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asAttacker(), 'users', PROVIDER), {
      rating: 5,
      totalRatings: 100,
      ratingOrderId: 'order-made-up',
      updatedAt: new Date(),
    }),
  );
});

await it('a reviewer CAN update the reviewee aggregate with proof', async () => {
  await reset();
  const order = newOrderDoc({ status: 'completed' });
  await seed('orders/order-ok', order);
  await seed(
    `reviews/order-ok`,
    newReviewDoc({ orderId: 'order-ok', reviewerId: CONSUMER, revieweeId: PROVIDER }),
  );
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'users', PROVIDER), {
      rating: 5,
      totalRatings: 1,
      ratingOrderId: 'order-ok',
      updatedAt: new Date(),
    }),
  );
});

await it('a reviewer cannot forge proof for a different reviewee', async () => {
  await reset();
  await seed('orders/order-ok', newOrderDoc({ status: 'completed' }));
  await seed(
    `reviews/order-ok`,
    newReviewDoc({ orderId: 'order-ok', reviewerId: CONSUMER, revieweeId: PROVIDER }),
  );
  // Same review, but pointed at a different user.
  await assertFails(
    updateDoc(doc(asConsumer(), 'users', PROVIDER2), {
      rating: 5,
      totalRatings: 1,
      ratingOrderId: 'order-ok',
      updatedAt: new Date(),
    }),
  );
});

await it('a user cannot delete another user', async () => {
  await reset();
  await assertFails(deleteDoc(doc(asConsumer(), 'users', PROVIDER)));
});

// ---------------------------------------------------------------- listings

console.log('\nlistings');

await it('anonymous listing read is denied', async () => {
  await reset();
  await assertFails(getDoc(doc(anon(), 'listings', 'listing-1')));
});

await it('a signed-in consumer can browse listings', async () => {
  await reset();
  await assertSucceeds(getDoc(doc(asConsumer(), 'listings', 'listing-1')));
});

await it('a consumer cannot publish a listing', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asConsumer(), 'listings', 'rogue'), newListingDoc({
      providerId: CONSUMER,
    })),
  );
});

await it('a provider cannot publish under someone else\'s id', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asProvider(), 'listings', 'rogue'), newListingDoc({
      providerId: PROVIDER2,
    })),
  );
});

await it('a provider can publish a valid listing', async () => {
  await reset();
  await assertSucceeds(
    setDoc(doc(asProvider(), 'listings', 'fresh'), newListingDoc()),
  );
});

await it('a provider cannot publish with discounted > original', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asProvider(), 'listings', 'bad-price'), newListingDoc({
      originalPrice: 10,
      discountedPrice: 500,
    })),
  );
});

await it('a provider cannot publish a listing with no images', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asProvider(), 'listings', 'no-img'), newListingDoc({ images: [] })),
  );
});

await it('a provider can edit their own listing', async () => {
  await reset();
  await assertSucceeds(
    updateDoc(doc(asProvider(), 'listings', 'listing-1'), {
      title: 'Even fresher bread',
      updatedAt: new Date(),
    }),
  );
});

await it('a provider cannot transfer a listing to another owner', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asProvider(), 'listings', 'listing-1'), {
      providerId: PROVIDER2,
      updatedAt: new Date(),
    }),
  );
});

await it('a non-owner cannot edit listing details', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      title: 'Hacked',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CAN decrement stock to reserve it', async () => {
  await reset();
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 8,
      status: 'available',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CAN mark a listing reserved at zero stock', async () => {
  await reset();
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 0,
      status: 'reserved',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CANNOT increase stock', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 9999,
      status: 'available',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CANNOT force a listing to completed', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 0,
      status: 'completed',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CANNOT force a listing to expired', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 0,
      status: 'expired',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer CANNOT decimate stock to zero and mark it completed', async () => {
  await reset();
  await assertFails(
    updateDoc(doc(asConsumer(), 'listings', 'listing-1'), {
      quantity: 0,
      status: 'completed',
      updatedAt: new Date(),
    }),
  );
});

await it('a buyer cannot delete a listing', async () => {
  await reset();
  await assertFails(deleteDoc(doc(asConsumer(), 'listings', 'listing-1')));
});

// ---------------------------------------------------------------- orders

console.log('\norders');

await it('anonymous order read is denied', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertFails(getDoc(doc(anon(), 'orders', 'order-1')));
});

await it('the buyer can read their order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertSucceeds(getDoc(doc(asConsumer(), 'orders', 'order-1')));
});

await it('the provider can read the order addressed to them', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertSucceeds(getDoc(doc(asProvider(), 'orders', 'order-1')));
});

await it('an unrelated user cannot read the order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertFails(getDoc(doc(asAttacker(), 'orders', 'order-1')));
});

await it('a buyer can place a pending order', async () => {
  await reset();
  await assertSucceeds(
    addDoc(collection(asConsumer(), 'orders'), newOrderDoc()),
  );
});

await it('a buyer cannot create an order already marked completed', async () => {
  await reset();
  await assertFails(
    addDoc(collection(asConsumer(), 'orders'), newOrderDoc({ status: 'completed' })),
  );
});

await it('a buyer cannot order more than the listing has', async () => {
  await reset();
  await assertFails(
    addDoc(collection(asConsumer(), 'orders'), newOrderDoc({ quantity: 9999 })),
  );
});

await it('a buyer cannot order against a sold-out listing', async () => {
  await reset();
  await seed('listings/listing-1', newListingDoc({ quantity: 0 }));
  await assertFails(addDoc(collection(asConsumer(), 'orders'), newOrderDoc()));
});

await it('a provider cannot order from themselves', async () => {
  await reset();
  await seed('listings/listing-1', newListingDoc({ providerId: PROVIDER }));
  await assertFails(
    addDoc(collection(asProvider(), 'orders'), newOrderDoc({ buyerId: PROVIDER })),
  );
});

await it('the provider can confirm a pending order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertSucceeds(
    updateDoc(doc(asProvider(), 'orders', 'order-1'), {
      status: 'confirmed',
      updatedAt: new Date(),
    }),
  );
});

await it('the provider can mark a confirmed order picked up', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'confirmed' }));
  await assertSucceeds(
    updateDoc(doc(asProvider(), 'orders', 'order-1'), {
      status: 'picked_up',
      updatedAt: new Date(),
    }),
  );
});

await it('the provider CANNOT skip straight to completed', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertFails(
    updateDoc(doc(asProvider(), 'orders', 'order-1'), {
      status: 'completed',
      updatedAt: new Date(),
    }),
  );
});

await it('the buyer can confirm collection of a picked-up order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'picked_up' }));
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'orders', 'order-1'), {
      status: 'completed',
      updatedAt: new Date(),
    }),
  );
});

await it('the buyer CANNOT cancel after pickup', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'picked_up' }));
  await assertFails(
    updateDoc(doc(asConsumer(), 'orders', 'order-1'), {
      status: 'cancelled',
      updatedAt: new Date(),
    }),
  );
});

await it('the buyer can cancel a pending order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertSucceeds(
    updateDoc(doc(asConsumer(), 'orders', 'order-1'), {
      status: 'cancelled',
      cancellationReason: 'Changed my mind',
      updatedAt: new Date(),
    }),
  );
});

await it('the provider can decline a pending order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertSucceeds(
    updateDoc(doc(asProvider(), 'orders', 'order-1'), {
      status: 'cancelled',
      cancellationReason: 'Sold out',
      updatedAt: new Date(),
    }),
  );
});

await it('the provider can mark stock restored on a cancelled order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'cancelled' }));
  await assertSucceeds(
    updateDoc(doc(asProvider(), 'orders', 'order-1'), { stockRestored: true }),
  );
});

await it('the buyer CANNOT mark stock restored', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'cancelled' }));
  await assertFails(
    updateDoc(doc(asConsumer(), 'orders', 'order-1'), { stockRestored: true }),
  );
});

await it('a cancelled order is never deletable by the client', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'cancelled' }));
  await assertFails(deleteDoc(doc(asProvider(), 'orders', 'order-1')));
  await assertFails(deleteDoc(doc(asConsumer(), 'orders', 'order-1')));
});

await it('an unrelated user cannot mutate the order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc());
  await assertFails(
    updateDoc(doc(asAttacker(), 'orders', 'order-1'), {
      status: 'confirmed',
      updatedAt: new Date(),
    }),
  );
});

// ---------------------------------------------------------------- reviews

console.log('\nreviews');

await it('a buyer can review a completed order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  await assertSucceeds(
    setDoc(doc(asConsumer(), 'reviews', 'order-1'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: CONSUMER,
      revieweeId: PROVIDER,
    })),
  );
});

await it('a review doc id must equal its orderId', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  await assertFails(
    setDoc(doc(asConsumer(), 'reviews', 'some-other-id'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: CONSUMER,
      revieweeId: PROVIDER,
    })),
  );
});

await it('the second review on one order is rejected', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  await seed(
    'reviews/order-1',
    newReviewDoc({ orderId: 'order-1', reviewerId: CONSUMER, revieweeId: PROVIDER }),
  );
  // Same path again (overwrite) must fail, and a differently-named doc must
  // fail the id-matches-orderId check.
  await assertFails(
    setDoc(doc(asConsumer(), 'reviews', 'order-1'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: CONSUMER,
      revieweeId: PROVIDER,
    })),
  );
  await assertFails(
    setDoc(doc(asConsumer(), 'reviews', 'order-1-second'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: CONSUMER,
      revieweeId: PROVIDER,
    })),
  );
});

await it('a buyer cannot review an order that is not completed', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'confirmed' }));
  await assertFails(
    setDoc(doc(asConsumer(), 'reviews', 'order-1'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: CONSUMER,
      revieweeId: PROVIDER,
    })),
  );
});

await it('a non-buyer cannot review an order', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  await assertFails(
    setDoc(doc(asAttacker(), 'reviews', 'order-1'), newReviewDoc({
      orderId: 'order-1',
      reviewerId: ATTACKER,
      revieweeId: PROVIDER,
    })),
  );
});

await it('a rating outside 1-5 is rejected', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  for (const rating of [0, 6, -1]) {
    await assertFails(
      setDoc(doc(asConsumer(), 'reviews', `order-${rating}`), newReviewDoc({
        orderId: `order-${rating}`,
        reviewerId: CONSUMER,
        revieweeId: PROVIDER,
        rating,
      })),
    );
  }
});

await it('reviews are immutable', async () => {
  await reset();
  await seed('orders/order-1', newOrderDoc({ status: 'completed' }));
  await seed(
    'reviews/order-1',
    newReviewDoc({ orderId: 'order-1', reviewerId: CONSUMER, revieweeId: PROVIDER }),
  );
  await assertFails(
    updateDoc(doc(asConsumer(), 'reviews', 'order-1'), { rating: 1 }),
  );
  await assertFails(deleteDoc(doc(asConsumer(), 'reviews', 'order-1')));
});

// ---------------------------------------------------------------- chat

console.log('\nchat');

const room = (over = {}) => ({
  participants: [CONSUMER, PROVIDER],
  participantNames: { [CONSUMER]: 'Consumer', [PROVIDER]: 'Bakery' },
  lastMessage: '',
  lastMessageTime: new Date(),
  ...over,
});

await it('a participant can create a two-person room', async () => {
  await reset();
  await assertSucceeds(setDoc(doc(asConsumer(), 'chat_rooms', 'room-1'), room()));
});

await it('a room with three participants is rejected', async () => {
  await reset();
  await assertFails(
    setDoc(doc(asConsumer(), 'chat_rooms', 'room-bad'), room({
      participants: [CONSUMER, PROVIDER, ATTACKER],
      participantNames: {
        [CONSUMER]: 'Consumer',
        [PROVIDER]: 'Bakery',
        [ATTACKER]: 'Attacker',
      },
    })),
  );
});

await it('a non-participant cannot read the room', async () => {
  await reset();
  await seed('chat_rooms/room-1', room());
  await assertFails(getDoc(doc(asAttacker(), 'chat_rooms', 'room-1')));
});

await it('a participant can send a message', async () => {
  await reset();
  await seed('chat_rooms/room-1', room());
  await assertSucceeds(
    setDoc(doc(asConsumer(), 'chat_rooms', 'room-1', 'messages', 'm1'), {
      senderId: CONSUMER,
      senderName: 'Consumer',
      text: 'Is this still available?',
      timestamp: new Date(),
    }),
  );
});

await it('a non-participant cannot send a message', async () => {
  await reset();
  await seed('chat_rooms/room-1', room());
  await assertFails(
    setDoc(doc(asAttacker(), 'chat_rooms', 'room-1', 'messages', 'm2'), {
      senderId: ATTACKER,
      senderName: 'Attacker',
      text: 'let me in',
      timestamp: new Date(),
    }),
  );
});

await it('a participant cannot rewrite the participant list', async () => {
  await reset();
  await seed('chat_rooms/room-1', room());
  await assertFails(
    updateDoc(doc(asConsumer(), 'chat_rooms', 'room-1'), {
      participants: [CONSUMER, ATTACKER],
      lastMessage: 'hi',
      lastMessageTime: new Date(),
      lastMessageSenderId: CONSUMER,
    }),
  );
});

await it('rooms cannot be deleted by participants', async () => {
  await reset();
  await seed('chat_rooms/room-1', room());
  await assertFails(deleteDoc(doc(asProvider(), 'chat_rooms', 'room-1')));
});

// ---------------------------------------------------------------- summary

await testEnv.cleanup();

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length > 0) {
  console.log('\nFailures:');
  for (const f of failures) console.log(` - ${f.name}: ${f.error.message}`);
  process.exit(1);
}