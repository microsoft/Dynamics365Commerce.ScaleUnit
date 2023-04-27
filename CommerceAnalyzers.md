## Commerce Analyzers

### AvoidBlockingCallsAnalyzer

Problem: Blocking calls lead to thread starvation and degraded response times.  See [best practices](https://docs.microsoft.com/en-us/aspnet/core/performance/performance-best-practices?view=aspnetcore-3.0#avoid-blocking-calls) for more information.
Do not:
1. Execute CRT requests synchronously:
   - It runs database queries synchronously blocking a thread while doing IO.
   - Commerce Runtime uses sync adapters for async request handlers that simply call ```.GetAwaiter().GetResult()``` which blocks threads and causes thread starvation issue under heavy load (see [this](https://docs.microsoft.com/en-us/archive/blogs/vancem/diagnosing-net-core-threadpool-starvation-with-perfview-why-my-service-is-not-saturating-all-cores-or-seems-to-stall) article for explanation).
2. Access database synchronously.
3. Block asynchronous execution by calling ```Task.Wait``` or ```Task.Result```.

Solution: Use ```async/await``` pattern for executing asynchronous operations to improve performance and scalability.

Example:
```cs
// Violation: Executing request synchronously
public class SomeRequestHandler : IRequestHandler
{
    protected override Response Process(Request request)
    {
        request.RequestContext.Execute<SomeResponse>(new SomeRequest);
    }
}

// Correct: Execute request asynchronously
[DataContract]
public class SomeRequestHandler : IRequestHandlerAsync
{
    protected override async Task<Response> Process(Request request)
    {
        await request.RequestContext.ExecuteAsync<SomeResponse>(new SomeRequest).ConfigureAwait(false);
    }
}
```

### AvoidAsyncVoidAnalyzer

Problem: Outside of event handlers and special edge cases, async void methods could lead to errors, problems with exception handling, etc. Described in more detail in [Async/Await - Best Practices in Asynchronous Programming](https://docs.microsoft.com/en-us/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming#avoid-async-void).

Solution: If method involves async functionality, use async Task instead. Otherwise, consider removing async. 

Example:
```cs
// Violation: Uses async void, could not be properly awaited.
async void Do()
{
    await Task.Run(() => { /*some code*/ });
}

// Correct: Uses async Task, could be properly awaited
async Task Do()
{
    await Task.Run(() => { /*some code*/ });
}
```

### CurrentCultureShouldNotBeUsedAnalyzer

Problem: Server-side code should use invariant culture to format strings.  

Solution: Use ```CultureInfo.InvariantCulture``` instead of ```CultureInfo.CurrentCulture``` in server-side code.

Example:
```cs
// Violation: Uses CultureInfo.CurrentCulture
string.Format(CultureInfo.CurrentCulture, "Some string");

// Correct: Contains only constants
string.Format(CultureInfo.InvariantCulture, "Some string");
```

### PreventSqlInjectionAnalyzer

Problem: Using values other than literals and constants in an expression assigned to ```SqlPagedQuery.Where``` is not safe in terms of SQL injection.  

Solution: Use only literals and constants in an expression assigned to ```SqlPagedQuery.Where``` to prevent SQL injection. Expression can contain interpolated strings, string concatenations and System.String method calls.

Example:
```cs
// Violation: Uses a variable in the expression assigned to SqlPagedQuery.Where
public void BuildQuery()
{
    var query = new SqlPagedQuery();
    
    var whereClauses = new List<string>();
    whereClauses.Add("Id = @Id");
    whereClauses.Add("Name = @Name");

    query.Where = string.Join(" AND ", whereClauses);
}

// Correct: Uses interpolated string with constants
public class SomeClass
{
    private static class Columns
    {
        public const string Id = "Id";
        public const string Name = "Name";
    }
    
    public void BuildQuery()
    {
        var query = new SqlPagedQuery();

        query.Where = $"{Columns.Id} = @{Columns.Id} AND {Columns.Name} = @{Columns.Name}";
    }
}
```

### UseAsyncAwaitDiagnosticAnalyzer

Problem: Returning a ```Task``` inside ```try/catch``` or ```using``` block without using ```await``` leads to incorrect exception handling/disposed objects issue (see [async guidelines](https://msazure.visualstudio.com/D365/_git/Retail-Rainier-Channel?path=%2FAsyncGuidelines.md&version=GBmaster&_a=preview) for more details).  

Solution: Use ```async/await``` keywords in a method that returns ```Task``` if there's a return statement inside try or using block .

Example:
```cs
// Violation: This method returns a task without awaiting it. If exception is thrown, it won't be caught by the catch statement
public Task DoAsync()
{
    try
    {
        // This may throw an exception
        return service.DoAsync();
    }
    catch(SomeException)
    {
        // Exception won't be caught
    }
}

// Correct: Use async/await for correct exception handling
public async Task DoAsync()
{
    try
    {
        // This may throw an exception
        return await service.DoAsync();
    }
    catch(SomeException)
    {
        // Exception will be caught
    }
}
```

### UseControllerAttributesCorrectlyAnalyzer

Problem: Using a reserved route prefix for a controller in a CRT extension may cause built-in route to work incorrectly. Similarly, using a controller bound to built-in Commerce entity in an extension may break built-in functionality.

Solution: Only a custom route prefix can be used for a controller in a CRT extension. Also, a controller can only be bound to a custom entity.

Example:
```cs
// Violation: Using reserved route prefix and built-in entity
using Microsoft.Dynamics.Commerce.Runtime.DataModel;

[RoutePrefix("OrgUnits")]
[BindEntity(typeof(OrgUnit))]
public class SomeController : IController
{
}

// Correct: Using custom route prefix and custom entity
[RoutePrefix("Custom")]
[BindEntity(typeof(CustomEntity))]
public class SomeController : IController
{
}
```

### UseSystemDataAnnotationsAnalyzer

Problem: CRT extension developers may use `KeyAttribute` from CRT framework instead of `System.ComponentModel.DataAnnotations.KeyAttribute` by mistake to annotate primary key property in an entity type.

Solution: Use `System.ComponentModel.DataAnnotations.KeyAttribute` to annotate primary key property of an entity type.

Example:
```cs
// Violation: Using the wrong KeyAttribute
public class SomeEntity : CommerceEntity
{
    [Microsoft.Dynamics.Commerce.Runtime.ComponentModel.DataAnnotations.KeyAttribute]
    public int Id { get; set; }
}

// Correct: Using the right KeyAttribute
public class SomeEntity : CommerceEntity
{
    [System.ComponentModel.DataAnnotations.KeyAttribute]
    public int Id { get; set; }
}
```

## NET Analyzers

### [CA1827](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1827): Do not use ```Count/LongCount``` when ```Any``` can be used

Rule description: This rule flags the Count and LongCount LINQ method calls used to check if the collection has at least one element. These method calls require enumerating the entire collection to compute the count. The same check is faster with the Any method as it avoids enumerating the collection.

### [CA1828](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1828): Do not use ```CountAsync/LongCountAsync``` when ```AnyAsync``` can be used

Rule description: This rule flags the ```CountAsync``` and ```LongCountAsync``` LINQ method calls used to check if the collection has at least one element. These method calls require enumerating the entire collection to compute the count. The same check is faster with the ```AnyAsync``` method as it avoids enumerating the collection.

### [CA1829](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1829): Use ```Length/Count``` property instead of ```Enumerable.Count``` method

Rule description: This rule flags the ```Count``` LINQ method calls on collections of types that have equivalent, but more efficient ```Length``` or ```Count``` property to fetch the same data. ```Length``` or ```Count``` property does not enumerate the collection, hence is more efficient.

### [CA1835](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1835): Prefer the memory-based overloads of ```ReadAsync/WriteAsync``` methods in stream-based classes

Rule description: The memory-based method overloads have a more efficient memory usage than the byte array-based ones.

The rule works on ```ReadAsync``` and ```WriteAsync``` invocations of any class that inherits from Stream.

The rule only works when the method is preceded by the ```await``` keyword.

### [CA1836](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1836): Prefer ```IsEmpty``` over ```Count``` when available

Rule description: This rule flags the calls to the Count and Length properties or ```Count<TSource>```(```IEnumerable<TSource>```) and ```LongCount<TSource>```(```IEnumerable<TSource>```) LINQ methods when they are used to determine if the object contains any items and the object has a more efficient ```IsEmpty``` property.

### [CA1840](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1840): Use ```Environment.CurrentManagedThreadId``` instead of ```Thread.CurrentThread.ManagedThreadId```

Rule description: ```System.Environment.CurrentManagedThreadId``` is a compact and efficient replacement of the ```Thread.CurrentThread.ManagedThreadId``` pattern.

### [CA1841](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1841)

Rule description: Calling Contains on the Keys or Values collection can often be more expensive than calling ContainsKey or ContainsValue on the dictionary

### [CA1842](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1842): Do not use ```WhenAll``` with a single task

Rule description: Using ```WhenAll``` with a single task may result in performance loss.

### [CA1843](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1843): Do not use ```WaitAll``` with a single task

Rule description: Using ```WaitAll``` with a single task may result in performance loss.

### [CA1844](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1844): Provide memory-based overrides of async methods when subclassing ```Stream```

Rule description: The memory-based ReadAsync and WriteAsync methods were added to improve performance, which they accomplish in multiple ways:

 - They return ```ValueTask``` and ```ValueTask<int>``` instead of ```Task``` and ```Task<int>```, respectively.
 - They allow any type of buffer to be passed in without having to perform an extra copy to an array.

### [CA1846](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1846): Prefer ```AsSpan``` over ```Substring```

Rule description: ```Substring``` allocates a new string object on the heap and performs a full copy of the extracted text. String manipulation is a performance bottleneck for many programs. Allocating many small, short-lived strings on a hot path can create enough collection pressure to impact performance. The O(n) copies created by Substring become relevant when the substrings get large. The ```Span<T>``` and ```ReadOnlySpan<T>``` types were created to solve these performance problems.

Many APIs that accept strings also have overloads that accept a ```ReadOnlySpan<System.Char>``` argument. When such overloads are available, you can improve performance by calling ```AsSpan``` instead of Substring.

### [CA1847](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1847): Use ```string.Contains(char)``` instead of ```string.Contains(string)``` with single characters

Rule description: When searching for a single character, using ```string.Contains(char)``` offers better performance ```than string.Contains(string)```.

### [CA1849](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1849): Call ```async``` methods when in an ```async``` method

Rule description: In a method which is already asynchronous, calls to other methods should be to their async versions, where they exist.

### [CA1851](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1851): Possible multiple enumerations of ```IEnumerable``` collection

Rule description: Collection with ```IEnumerable``` or ```IEnumerable<T>``` type generated by many LINQ methods like Select or ```yield``` in C# or ```yield``` statement in Visual Basic has the ability to defer enumeration when it is generated. The enumeration will start as long as it is passed into enumeration LINQ methods like ```ElementAt``` or used in for each statement in C# or ```For``` ```Each```..```Next``` Statement in Visual Basic. The enumeration result is not calculated once and cached like ```Lazy```.

### [CA1854](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1854): Prefer the ```IDictionary.TryGetValue(TKey, out TValue)``` method

Rule description: When an element of an IDictionary is accessed, the indexer implementation checks for a null value by calling the ```IDictionary.ContainsKey``` method. If you also call ```IDictionary.ContainsKey``` in an if clause to guard a value lookup, two lookups are performed when only one is needed.

### [CA2000](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2000): Dispose objects before losing scope

Rule description: If a disposable object is not explicitly disposed before all references to it are out of scope, the object will be disposed at some indeterminate time when the garbage collector runs the finalizer of the object. Because an exceptional event might occur that will prevent the finalizer of the object from running, the object should be explicitly disposed instead.

### [CA2002](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2002): Do not lock on objects with weak identity

Rule description: An object is said to have a weak identity when it can be directly accessed across application domain boundaries. A thread that tries to acquire a lock on an object that has a weak identity can be blocked by a second thread in a different application domain that has a lock on the same object.

### [CA2007](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2007): Do not directly await a ```Task```

Rule description: When an asynchronous method awaits a ```Task``` directly, continuation usually occurs in the same thread that created the task, depending on the async context. This behavior can be costly in terms of performance and can result in a deadlock on the UI thread. Consider calling Task.```ConfigureAwait(Boolean)``` to signal your intention for continuation.

### [CA2013](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2013): Do not use ```ReferenceEquals``` with value types

Rule description: When comparing values using ```ReferenceEquals```, if objA and objB are value types, they are boxed before they are passed to the ```ReferenceEquals``` method. This means that even if both objA and objB represent the same instance of a value type, the ```ReferenceEquals``` method nevertheless returns false, as the following example shows.

### [CA3061](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca3061): Do not add schema by URL.

Rule description: Overload of ```XmlSchemaCollection.Add(String, String)``` is using ```XmlUrlResolver``` to specify external XML schema in the form of an URI. If the URI String is tainted, it may lead to parsing of a malicious XML schema, which allows for the inclusion of XML bombs and malicious external entities. This could allow a malicious attacker to perform a denial of service, information disclosure, or server-side request forgery attack

### [CA3075](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca3075): Insecure DTD Processing.

Rule description: A Document Type Definition (DTD) is one of two ways an XML parser can determine the validity of a document, as defined by the World Wide Web Consortium (W3C) Extensible Markup Language (XML) 1.0. This rule seeks properties and instances where untrusted data is accepted to warn developers about potential Information Disclosure threats or Denial of Service (DoS) attacks

### [CA3076](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca3076): Insecure XSLT Script Execution.

Rule description: XSLT is a World Wide Web Consortium (W3C) standard for transforming XML data. XSLT is typically used to write style sheets to transform XML data to other formats such as HTML, fixed-length text, comma-separated text, or a different XML format. Although prohibited by default, you may choose to enable it for your project.

### [CA3077](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca3077): Insecure Processing in API Design, XML Document and XML Text Reader.

Rule description: A Document Type Definition (DTD) is one of two ways an XML parser can determine the validity of a document, as defined by the World Wide Web Consortium (W3C) Extensible Markup Language (XML) 1.0. This rule seeks properties and instances where untrusted data is accepted to warn developers about potential Information Disclosure threats, which may lead to Denial of Service (DoS) attacks

### [CA3147](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca3147): Mark verb handlers with ValidateAntiForgeryToken.

Rule description: When designing an ASP.NET MVC controller, be mindful of cross-site request forgery attacks. A cross-site request forgery attack can send malicious requests from an authenticated user to your ASP.NET MVC controller.

### [CA5350](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5350): Do Not Use Weak Cryptographic Algorithms.

Rule description: Weak encryption algorithms and hashing functions are used today for a number of reasons, but they should not be used to guarantee the confidentiality of the data they protect.

The rule triggers when it finds 3DES, SHA1 or RIPEMD160 algorithms in the code and throws a warning to the user.

### [CA5351](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5351): Do Not Use Broken Cryptographic Algorithms

Rule description: Broken cryptographic algorithms are not considered secure and their use should be discouraged. The MD5 hash algorithm is susceptible to known collision attacks, though the specific vulnerability will vary based on the context of use.

### [CA5359](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5359) : Do not disable certificate validation

Rule description: A certificate can help authenticate the identity of the server. Clients should validate the server certificate to ensure requests are sent to the intended server. If the ServicePointManager.ServerCertificateValidationCallback always returns ```true```, then by default any certificate will pass validation for all outgoing HTTPS requests.

### [CA5360](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5360) : Do not call dangerous methods in deserialization.

Rule description: nsecure deserialization is a vulnerability which occurs when untrusted data is used to abuse the logic of an application, inflict a Denial-of-Service (DoS) attack, or even execute arbitrary code upon it being deserialized. It's frequently possible for malicious users to abuse these deserialization features when the application is deserializing untrusted data which is under their control.

### [CA5363](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5363): Do not disable request validation.

Rule description: Request validation is a feature in ASP.NET that examines HTTP requests and determines whether they contain potentially dangerous content that can lead to injection attacks, including cross-site-scripting.

### [CA5364](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5364): Do not use deprecated security protocols.

Rule description: Transport Layer Security (TLS) secures communication between computers, most commonly with Hypertext Transfer Protocol Secure (HTTPS). Older protocol versions of TLS are less secure than TLS 1.2 and TLS 1.3 and are more likely to have new vulnerabilities. Avoid older protocol versions to minimize risk.

### [CA5365](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5365): Do Not Disable HTTP Header Checking.

Rule description: HTTP header checking enables encoding of the carriage return and newline characters, \r and \n, that are found in response headers. This encoding can help to avoid injection attacks that exploit an application that echoes untrusted data contained in the header

### [CA5366](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5366): Use XmlReader For DataSet Read XML.

Rule description: Using a ```System.Data.DataSet``` to read XML with untrusted data may load dangerous external references, which should be restricted by using an ```XmlReader``` with a secure resolver or with DTD processing disabled.

### [CA5368](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5368): Set ViewStateUserKey For Classes Derived From Page.

Rule description: When designing an ASP.NET Web Form, be mindful of cross-site request forgery (CSRF) attacks. A CSRF attack can send malicious requests from an authenticated user to your ASP.NET Web Form.

### [CA5369](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5369): Use XmlReader for Deserialize.

Rule description: Processing untrusted DTD and XML schemas may enable loading dangerous external references, which should be restricted by using an ```XmlReader``` with a secure resolver or with DTD and XML inline schema processing disabled. This rule detects code that uses the ```XmlSerializer.Deserialize``` method and does not take ```XmlReader``` as a constructor parameter.

### [CA5370](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5370): Use XmlReader for validating reader.

Rule description: Processing untrusted DTD and XML schemas may enable loading dangerous external references. This dangerous loading can be restricted by using an ```XmlReader``` with a secure resolver or with DTD and XML inline schema processing disabled. This rule detects code that uses the ```XmlValidatingReader``` class without ```XmlReader``` as a constructor parameter.

### [CA5371](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5371): Use XmlReader for schema read.

Rule description: Processing untrusted DTD and XML schemas may enable loading dangerous external references. Using an ```XmlReader``` with a secure resolver or with DTD and XML inline schema processing disabled restricts this. This rule detects code that uses the ```XmlSchema.Read``` method without ```XmlReader``` as a parameter.

### [CA5372](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5372): Use XmlReader for XPathDocument.

Rule description: Processing XML from untrusted data may load dangerous external references, which can be restricted by using an ```XmlReader``` with a secure resolver or with DTD processing disabled. This rule detects code that uses the ```XPathDocument``` class and doesn’t take ```XmlReader``` as a constructor parameter.

### [CA5373](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5373): Do not use obsolete key derivation function.

Rule description: This rule detects the invocation of weak key derivation methods System.Security.Cryptography.PasswordDeriveBytes and Rfc2898DeriveBytes.CryptDeriveKey. System.Security.Cryptography.PasswordDeriveBytes used a weak algorithm PBKDF1. Rfc2898DeriveBytes.CryptDeriveKey does not use iteration count and salt from the Rfc2898DeriveBytes object, which makes it weak.

### [CA5374](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5374): Do Not Use XslTransform.

Rule description: XslTransform is vulnerable when operating on untrusted input. An attack could execute arbitrary code.

### [CA5379](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5379): Ensure key derivation function algorithm is sufficiently strong.

Rule description: he Rfc2898DeriveBytes class defaults to using the SHA1 algorithm. When instantiating an Rfc2898DeriveBytes object, you should specify a hash algorithm of SHA256 or higher. Note that Rfc2898DeriveBytes.HashAlgorithm property only has a get accessor.

### [CA5384](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5384): Do not use digital signature algorithm (DSA).

Rule description: DSA is a weak asymmetric encryption algorithm.

### [CA5385](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca5385): Use Rivest–Shamir–Adleman (RSA) algorithm with sufficient key size. 

Rule description: An RSA key smaller than 2048 bits is more vulnerable to brute force attacks.

## Nuget warnings as errors

### [NU1701](https://docs.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1701)

Problem: PackageTargetFallback / AssetTargetFallback was used to select assets from a package. The warning let users know that the assets may not be 100% compatible.

### [NU1608](https://docs.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1608)

Problem: A resolved package is higher than a dependency constraint allows. This means that a package referenced directly by a project overrides dependency constraints from other packages.