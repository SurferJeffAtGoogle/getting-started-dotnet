﻿// Copyright 2015 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System.Threading;
using Xunit;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using GoogleCloudSamples.Models;
using System;
using Microsoft.Extensions.DependencyInjection;

namespace GoogleCloudSamples
{
    class FakeBookStore : IBookStore
    {
        public Book UpdatedBook = null;
        public void Create(Book book)
        {
            throw new NotImplementedException();
        }

        public void Delete(long id)
        {
            throw new NotImplementedException();
        }

        public BookList List(int pageSize, string nextPageToken)
        {
            throw new NotImplementedException();
        }

        public Book Read(long id)
        {
            return new Book()
            {
                Id = 3,
                Title = "test.js"
            };
        }

        public void Update(Book book)
        {
            UpdatedBook = book;
        }
    }

    public class BookDetailLookupTest
    {
        static readonly string _projectId;
        static BookDetailLookupTest()
        {
            _projectId = System.Environment.GetEnvironmentVariable("GOOGLE_PROJECT_ID");
            Assert.False(string.IsNullOrWhiteSpace(_projectId), "Set the environment variable " +
                "GOOGLE_PROJECT_ID to your google project id.");
        }

        [Fact]
        public void TestPubsub()
        {
            var options = new BookDetailLookup.Options();
            options.SubscriptionName += "-test";
            options.TopicName += "-test";
            BookDetailLookup bookDetailLookup = 
                new BookDetailLookup(_projectId, new LoggerFactory(), options);
            bookDetailLookup.CreateTopicAndSubscription();
            bookDetailLookup.EnqueueBook(45);
            var cancel = new CancellationTokenSource();
            var pullTask = Task.Factory.StartNew(() => bookDetailLookup.PullLoop((long bookId) =>
            {
                Assert.Equal(45, bookId);
                cancel.Cancel();
            }, cancel.Token));
            pullTask.Wait();
        }

        [Fact]
        public void TestProcessBook()
        {
            FakeBookStore bookStore = new FakeBookStore();
            BookDetailLookup.ProcessBook(bookStore, 3);
            Assert.Equal(3, bookStore.UpdatedBook.Id);
            Assert.Equal("Test-Driven JavaScript Development", bookStore.UpdatedBook.Title);
            Assert.Equal("Christian Johansen", bookStore.UpdatedBook.Author);
        }

        [Fact]
        public void TestLoop()
        {
            var options = new BookDetailLookup.Options();
            options.SubscriptionName += "-test";
            options.TopicName += "-test";
            BookDetailLookup bookDetailLookup =
                new BookDetailLookup(_projectId, new LoggerFactory(), options);
            bookDetailLookup.CreateTopicAndSubscription();
            var cancel = new CancellationTokenSource();
            var pullTask = bookDetailLookup.StartPullLoop(new FakeBookStore(), cancel.Token);
            cancel.CancelAfter(100);
            pullTask.Wait();
        }
    }
}
